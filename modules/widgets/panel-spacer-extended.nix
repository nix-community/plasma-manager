{ lib, ... }:
let
  inherit (lib) mkOption types;

  actionType = types.submodule {
    options = {
      action = mkOption {
        type = types.str;
        example = "pausemedia";
        description = "The action to perform.";
      };
      component = mkOption {
        type = types.str;
        example = "mediacontrol";
        description = "The component to perform the action on.";
      };
      command = mkOption {
        type = types.nullOr types.str;
        default = null;
        example = ''date="$(date -u)"; notify-send "Single Click" "$date"'';
        description = "The command to log.";
      };
      appUrl = mkOption {
        type = types.nullOr types.str;
        default = null;
        description = "The application URL";
      };
    };
  };
in {
  panelSpacerExtended = {
    description = "Spacer with Mouse gestures for the KDE Plasma Panel featuring Latte Dock/Gnome/Unity drag window gesture.";

    opts = {
      expanding = mkOption {
        type = types.nullOr types.bool;
        default = null;
        example = true;
        description = "Whether the spacer should expand to fill the available space.";
      };
      length = mkOption {
        type = types.nullOr types.ints.unsigned;
        default = null;
        example = 32;
        description = ''
          The length in pixels of the spacer.
          Configuration effective only if expanding is set to false.
        '';
      };
      highlight = {
        enable = mkOption {
          type = types.nullOr types.bool;
          default = null;
          example = true;
          description = "Whether the spacer should highlight when hovered.";
        };
        radius = mkOption {
          type = types.nullOr types.ints.unsigned;
          default = null;
          example = 4;
          description = ''
            The radius in pixels of the highlight.
            Configuration effective only if enable is set to true.
          '';
        };
        fillPanel = mkOption {
          type = types.nullOr types.bool;
          default = null;
          example = true;
          description = ''
            Whether the highlight should fill the entire panel.
            Configuration effective only if enable is set to true.
          '';
        };
      };
      showTooltip = mkOption {
        type = types.nullOr types.bool;
        default = null;
        example = true;
        description = "Whether to show list of actions when hovering the spacer.";
      };
      screenWidth = mkOption {
        type = types.nullOr types.ints.positive;
        default = null;
        example = 1920;
        description = "The screen width in pixels.";
      };
      scrollThreshold = mkOption {
        type = types.nullOr types.ints.unsigned;
        default = null;
        example = 10;
        description = ''
          The scroll sensitivity

          Higher values may help reducing repeated scrolling events on some devices.
        '';
      };
      actions = {
        singleClick = mkOption {
          type = types.nullOr actionType;
          default = null;
          example = {
            action = "pausemedia";
            component = "mediacontrol";
          };
          description = "The action to perform on single click.";
          apply = singleClick: let
            convertAction = action: component: "${component},${action}";
          in lib.optionalAttrs (singleClick != null) lib.filterAttrs (_: v: v != null) ({
            singleClickAction = convertAction singleClick.action singleClick.component;
            singleClickCommand = singleClick.command;
            singleClickAppUrl = singleClick.appUrl;
          });
        };
        doubleClick = mkOption {
          type = types.nullOr actionType;
          default = null;
          example = {
            action = "pausemedia";
            component = "mediacontrol";
          };
          description = "The action to perform on double click.";
          apply = doubleClick: let
            convertAction = action: component: "${component},${action}";
          in lib.optionalAttrs (doubleClick != null) lib.filterAttrs (_: v: v != null) ({
            doubleClickAction = convertAction doubleClick.action doubleClick.component;
            doubleClickCommand = doubleClick.command;
            doubleClickAppUrl = doubleClick.appUrl;
          });
        };
        middleClick = mkOption {
          type = types.nullOr actionType;
          default = null;
          example = {
            action = "pausemedia";
            component = "mediacontrol";
          };
          description = "The action to perform on middle click.";
          apply = middleClick: let
            convertAction = action: component: "${component},${action}";
          in lib.optionalAttrs (middleClick != null) lib.filterAttrs (_: v: v != null) ({
            middleClickAction = convertAction middleClick.action middleClick.component;
            middleClickCommand = middleClick.command;
            middleClickAppUrl = middleClick.appUrl;
          });
        };
        mouseWheelUp = mkOption {
          type = types.nullOr actionType;
          default = null;
          example = {
            action = "pausemedia";
            component = "mediacontrol";
          };
          description = "The action to perform on mouse wheel up.";
          apply = mouseWheelUp: let
            convertAction = action: component: "${component},${action}";
          in lib.optionalAttrs (mouseWheelUp != null) lib.filterAttrs (_: v: v != null) ({
            mouseWheelUpAction = convertAction mouseWheelUp.action mouseWheelUp.component;
            mouseWheelUpCommand = mouseWheelUp.command;
            mouseWheelUpAppUrl = mouseWheelUp.appUrl;
          });
        };
        mouseWheelDown = mkOption {
          type = types.nullOr actionType;
          default = null;
          example = {
            action = "pausemedia";
            component = "mediacontrol";
          };
          description = "The action to perform on mouse wheel down.";
          apply = mouseWheelDown: let
            convertAction = action: component: "${component},${action}";
          in lib.optionalAttrs (mouseWheelDown != null) lib.filterAttrs (_: v: v != null) ({
            mouseWheelDownAction = convertAction mouseWheelDown.action mouseWheelDown.component;
            mouseWheelDownCommand = mouseWheelDown.command;
            mouseWheelDownAppUrl = mouseWheelDown.appUrl;
          });
        };
        mouseDragUp = mkOption {
          type = types.nullOr actionType;
          default = null;
          example = {
            action = "pausemedia";
            component = "mediacontrol";
          };
          description = "The action to perform on mouse drag up.";
          apply = mouseDragUp: let
            convertAction = action: component: "${component},${action}";
          in lib.optionalAttrs (mouseDragUp != null) lib.filterAttrs (_: v: v != null) ({
            mouseDragUpAction = convertAction mouseDragUp.action mouseDragUp.component;
            mouseDragUpCommand = mouseDragUp.command;
            mouseDragUpAppUrl = mouseDragUp.appUrl;
          });
        };
        mouseDragDown = mkOption {
          type = types.nullOr actionType;
          default = null;
          example = {
            action = "pausemedia";
            component = "mediacontrol";
          };
          description = "The action to perform on mouse drag down.";
          apply = mouseDragDown: let
            convertAction = action: component: "${component},${action}";
          in lib.optionalAttrs (mouseDragDown != null) lib.filterAttrs (_: v: v != null) ({
            mouseDragDownAction = convertAction mouseDragDown.action mouseDragDown.component;
            mouseDragDownCommand = mouseDragDown.command;
            mouseDragDownAppUrl = mouseDragDown.appUrl;
          });
        };
        mouseDragLeft = mkOption {
          type = types.nullOr actionType;
          default = null;
          example = {
            action = "pausemedia";
            component = "mediacontrol";
          };
          description = "The action to perform on mouse drag left.";
          apply = mouseDragLeft: let
            convertAction = action: component: "${component},${action}";
          in lib.optionalAttrs (mouseDragLeft != null) lib.filterAttrs (_: v: v != null) ({
            mouseDragLeftAction = convertAction mouseDragLeft.action mouseDragLeft.component;
            mouseDragLeftCommand = mouseDragLeft.command;
            mouseDragLeftAppUrl = mouseDragLeft.appUrl;
          });
        };
        mouseDragRight = mkOption {
          type = types.nullOr actionType;
          default = null;
          example = {
            action = "pausemedia";
            component = "mediacontrol";
          };
          description = "The action to perform on mouse drag right.";
          apply = mouseDragRight: let
            convertAction = action: component: "${component},${action}";
          in lib.optionalAttrs (mouseDragRight != null) lib.filterAttrs (_: v: v != null) ({
            mouseDragRightAction = convertAction mouseDragRight.action mouseDragRight.component;
            mouseDragRightCommand = mouseDragRight.command;
            mouseDragRightAppUrl = mouseDragRight.appUrl;
          });
        };
        longPress = mkOption {
          type = types.nullOr actionType;
          default = null;
          example = {
            action = "pausemedia";
            component = "mediacontrol";
          };
          description = "The action to perform on long press.";
          apply = longPress: let
            convertAction = action: component: "${component},${action}";
          in lib.optionalAttrs (longPress != null) lib.filterAttrs (_: v: v != null) ({
            pressHoldAction = convertAction longPress.action longPress.component;
            pressHoldCommand = longPress.command;
            pressHoldAppUrl = longPress.appUrl;
          });
        };
      };
      troubleshooting = {
        debugMessages.enable = mkOption {
          type = types.nullOr types.bool;
          default = null;
          example = true;
          description = "Whether to enable debug messages.";
        };
      };
      settings = mkOption {
        type = with types; nullOr (attrsOf (attrsOf (either (oneOf [ bool float int str ]) (listOf (oneOf [ bool float int str ])))));
        default = null;
        example = {
          General = {
            expanding = true;
          };
        };
        description = ''
          Extra configuration for the widget

          See available options at https://github.com/antroids/application-title-bar/blob/main/package/contents/config/main.xml
        '';
        apply = settings: if settings == null then {} else settings;
      };
    };

    convert =
      { expanding
      , length
      , highlight
      , showTooltip
      , screenWidth
      , scrollThreshold
      , actions
      , troubleshooting
      , settings
      }: {
      name = "luisbocanegra.panelspacer.extended";
      config = lib.recursiveUpdate {
        General = lib.filterAttrs (_: v: v != null) (
          {
            inherit expanding length showTooltip screenWidth;
            
            showHoverBg = highlight.enable;
            hoverBgRadius = highlight.radius;
            bgFillPanel = highlight.fillPanel;

            scrollSensitivity = scrollThreshold;

            enableDebug = troubleshooting.debugMessages.enable;
          }
          // actions.singleClick
          // actions.doubleClick
          // actions.middleClick
          // actions.mouseWheelUp
          // actions.mouseWheelDown
          // actions.mouseDragUp
          // actions.mouseDragDown
          // actions.mouseDragLeft
          // actions.mouseDragRight
          // actions.longPress
        );
      } settings;
    };
  };
}