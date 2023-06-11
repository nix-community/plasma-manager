#!/usr/bin/env ruby

################################################################################
#
# This file is part of the package Plasma Manager.  It is subject to
# the license terms in the LICENSE file found in the top-level
# directory of this distribution and at:
#
#   https://github.com/pjones/plasma-manager
#
# No part of this package, including this file, may be copied,
# modified, propagated, or distributed except according to the terms
# contained in the LICENSE file.
#
################################################################################
require("optparse")
require("pathname")

################################################################################
module Rc2Nix

  ##############################################################################
  # The root directory where configuration files are stored.
  XDG_CONFIG_HOME = File.expand_path(ENV["XDG_CONFIG_HOME"] || "~/.config")

  ##############################################################################
  # Files that we'll scan by default.
  KNOWN_FILES = [
    "kcminputrc",
    "kglobalshortcutsrc",
    "kactivitymanagerdrc",
    "ksplashrc",
    "kwin_rules_dialogrc",
    "kmixrc",
    "kwalletrc",
    "kgammarc",
    "krunnerrc",
    "klaunchrc",
    "plasmanotifyrc",
    "systemsettingsrc",
    "kscreenlockerrc",
    "kwinrulesrc",
    "khotkeysrc",
    "ksmserverrc",
    "kded5rc",
    "plasmarc",
    "kwinrc",
    "kdeglobals",
    "baloofilerc",
    "dolphinrc",
    "klipperrc",
    "plasma-localerc",
    "kxkbrc",
    "ffmpegthumbsrc",
    "kservicemenurc",
    "kiorc",
  ].map {|f| File.expand_path(f, XDG_CONFIG_HOME)}.freeze

  ##############################################################################
  class RcFile

    ############################################################################
    # Any group that matches a listed regular expression is blocked
    # from being passed through to the settings attribute.
    #
    # This is necessary because KDE currently stores application state
    # in configuration files.
    GROUP_BLOCK_LIST = [
      /^(ConfigDialog|FileDialogSize|ViewPropertiesDialog|KPropertiesDialog)$/,
      /^\$Version$/,
      /^ColorEffects:/,
      /^Colors:/,
      /^DoNotDisturb$/,
      /^LegacySession:/,
      /^MainWindow$/,
      /^PlasmaViews/,
      /^ScreenConnectors$/,
      /^Session:/,
    ]

    ############################################################################
    # Similar to the GROUP_BLOCK_LIST but for setting keys.
    KEY_BLOCK_LIST = [
      /^activate widget \d+$/, # Depends on state :(
      /^ColorScheme(Hash)?$/,
      /^History Items/,
      /^LookAndFeelPackage$/,
      /^Recent (Files|URLs)/,
      /^Theme$/i,
      /^Version$/,
      /State$/,
      /Timestamp$/,
    ]

    ############################################################################
    # List of functions that get called with a group name and a key
    # name.  If the function returns +true+ then block that key.
    BLOCK_LIST_LAMBDA = [
      ->(group, key) { group == "org.kde.kdecoration2" && key == "library" }
    ]

    ############################################################################
    attr_reader(:file_name, :settings)

    ############################################################################
    def initialize(file_name)
      @file_name = file_name
      @settings = {}
      @last_group = nil
    end

    ############################################################################
    def parse
      File.open(@file_name) do |file|
        file.each do |line|
          case line
          when /^\s*$/
            next
          when /^\s*(\[[^\]]+\]){1,}\s*$/
            @last_group = parse_group(line.strip)
          when /^\s*([^=]+)=?(.*)\s*$/
            key = $1.strip
            val = $2.strip

            if @last_group.nil?
              raise("#{@file_name}: setting outside of group: #{line}")
            end

            # Reasons to skip this group or key:
            next if GROUP_BLOCK_LIST.any? {|re| @last_group.match(re)}
            next if KEY_BLOCK_LIST.any? {|re| key.match(re)}
            next if BLOCK_LIST_LAMBDA.any? {|fn| fn.call(@last_group, key)}
            next if File.basename(@file_name) == "plasmanotifyrc" && key == "Seen"

            @settings[@last_group] ||= {}
            @settings[@last_group][key] = val
          else
            raise("#{@file_name}: can't parse line: #{line}")
          end
        end
      end
    end

    ############################################################################
    def parse_group(line)
      line.gsub(/\s*\[([^\]]+)\]\s*/) do |match|
        $1 + "."
      end.sub(/\.$/, '')
    end
  end

  ##############################################################################
  class App

    ############################################################################
    def initialize(args)
      @files = KNOWN_FILES.dup

      OptionParser.new do |p|
        p.on("-h", "--help", "This message") {$stdout.puts(p); exit}

        p.on("-c", "--clear", "Clear the file list") do
          @files = []
        end

        p.on("-a", "--add=FILE", "Add a file to the scan list") do |file|
          @files << File.expand_path(file)
        end
      end.parse!(args)
    end

    ############################################################################
    def run
      settings = {}

      @files.each do |file|
        next unless File.exist?(file)

        rc = RcFile.new(file)
        rc.parse

        path = Pathname.new(file).relative_path_from(XDG_CONFIG_HOME)
        settings[File.path(path)] = rc.settings
      end

      puts("{")
      puts("  programs.plasma = {")
      puts("    enable = true;")
      puts("    shortcuts = {")
      pp_shortcuts(settings["kglobalshortcutsrc"], 6)
      puts("    };")
      puts("    configFile = {")
      pp_settings(settings, 6)
      puts("    };")
      puts("  };")
      puts("}")
    end

    ############################################################################
    def pp_settings(settings, indent)
      settings.keys.sort.each do |file|
        settings[file].keys.sort.each do |group|
          settings[file][group].keys.sort.each do |key|
            next if file == "kglobalshortcutsrc" && key != "_k_friendly_name"

            print(" " * indent)
            print("\"#{file}\".")
            print("\"#{group}\".")
            print("\"#{key}\" = ")
            print(nix_val(settings[file][group][key]))
            print(";\n")
          end
        end
      end
    end

    ############################################################################
    def pp_shortcuts(groups, indent)
      return if groups.nil?

      groups.keys.sort.each do |group|
        groups[group].keys.sort.each do |action|
          next if action == "_k_friendly_name"

          print(" " * indent)
          print("\"#{group}\".")
          print("\"#{action}\" = ")

          keys = groups[group][action].
            split(/(?<!\\),/).first.to_s.
            gsub(/\\?\\,/, ',').
            gsub(/\\t/, "\t").
            split(/\t/)

          if keys.empty?
            print("[ ]")
          elsif keys.size > 1
            print("[" + keys.map {|k| nix_val(k)}.join(" ") + "]")
          elsif keys.first == "none"
            print("[ ]")
          else
            print(nix_val(keys.first))
          end

          print(";\n")
        end
      end
    end

    ############################################################################
    def nix_val(str)
      case str
      when NilClass
        "null"
      when /^true|false$/i
        str.downcase
      when /^[0-9]+(\.[0-9]+)?$/
        str
      else
        '"' + str.gsub(/(?<!\\)"/, '\\"') + '"'
      end
    end
  end
end

Rc2Nix::App.new(ARGV).run
