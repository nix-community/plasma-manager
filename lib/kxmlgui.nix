{ lib, ... }:
let
  boolToString = bool: if bool then "1" else "0";

  propertyType = lib.types.submodule {
    options = {
      name = lib.mkOption {
        type = lib.types.str;
        description = "The name of the property.";
      };
      shortcut = lib.mkOption {
        type = lib.types.str;
        description = "The shortcut of the property.";
      };
    };
  };

  actionPropertiesType = lib.types.submodule {
    options = {
      scheme = lib.mkOption {
        type = lib.types.str;
        description = "The scheme of the action properties.";
      };
      properties = lib.mkOption {
        type = lib.types.listOf propertyType;
        description = "The properties of the action properties.";
      };
    };
  };

  toolbarType = lib.types.submodule {
    options = {
      alreadyVisited = lib.mkOption {
        type = with lib.types; nullOr bool;
        default = null;
        example = true;
        description = "Whether the toolbar has already been visited.";
        apply = value: if value != null then boolToString value else null;
      };
      noMerge = lib.mkOption {
        type = with lib.types; nullOr bool;
        default = null;
        example = true;
        description = "Whether the toolbar should not be merged.";
        apply = value: if value != null then boolToString value else null;
      };
      items = lib.mkOption {
        type = lib.types.listOf itemType;
        description = "The items of the toolbar.";
      };
    };
  };

  itemType = lib.types.submodule {
    options = {
      type = lib.mkOption {
        type = lib.types.enum [
          "action"
          "group"
          "text"
          "separator"
        ];
        description = "The type of the item.";
        example = "action";
      };
      group = lib.mkOption {
        type = with lib.types; nullOr str;
        default = null;
        description = "The group of the item.";
      };
      value = lib.mkOption {
        type = lib.types.str;
        description = "The value of the item.";
      };
    };
  };

  menuType = lib.types.submodule {
    options = {
      name = lib.mkOption {
        type = lib.types.str;
        description = "The name of the menu.";
      };
      items = lib.mkOption {
        type = lib.types.listOf itemType;
        description = "The items of the menu.";
      };
    };
  };

  menuBarType = lib.types.submodule {
    options = {
      alreadyVisited = lib.mkOption {
        type = with lib.types; nullOr bool;
        default = null;
        example = true;
        description = "Whether the menu bar has already been visited.";
        apply = value: if value != null then boolToString value else null;
      };
      noMerge = lib.mkOption {
        type = with lib.types; nullOr bool;
        default = null;
        example = true;
        description = "Whether the menu bar should not be merged.";
        apply = value: if value != null then boolToString value else null;
      };
      menus = lib.mkOption {
        type = lib.types.listOf menuType;
        description = "The menus of the menu bar.";
      };
    };
  };

  kxmlguiType = lib.types.submodule {
    options = {
      name = lib.mkOption {
        type = lib.types.str;
        description = "The name of the configuration.";
      };
      version = lib.mkOption {
        type = lib.types.ints.unsigned;
        description = "The version of the configuration.";
      };
      translationDomain = lib.mkOption {
        type = with lib.types; nullOr str;
        default = null;
        example = "kxmlgui6";
        description = "The translation domain of the configuration";
      };
      menubar = lib.mkOption {
        type = lib.types.nullOr menuBarType;
        default = null;
        description = "The menu bar of the configuration.";
      };
      toolbar = lib.mkOption {
        type = lib.types.nullOr toolbarType;
        default = null;
        description = "The toolbar of the configuration.";
      };
      actionProperties = lib.mkOption {
        type = lib.types.nullOr actionPropertiesType;
        default = null;
        description = "The action properties of the configuration.";
      };
    };
  };

  generateKXMLGUI =
    name: version: translationDomain: menubar: toolbar: actionProperties:
    let
      generateItem =
        item:
        if item.type == "action" then
          ''<Action ${
            lib.optionalString (item.group != null) ''group="${item.group}"''
          } name="${item.value}"/>''
        else if item.type == "group" then
          ''<DefineGroup name="${item.value}"/>''
        else if item.type == "text" then
          "<text ${
            lib.optionalString (translationDomain != null) ''translationDomain="${translationDomain}"''
          } >${item.value}</text>"
        else
          "<Separator ${lib.optionalString (item.group != null) ''group="${item.group}"''}/>";
      generateActionProperty =
        property: ''<Action name="${property.name}" shortcut="${property.shortcut}">'';
    in
    ''
      <?xml version='1.0'?>
      <!DOCTYPE gui SYSTEM 'kpartgui.dtd'>
      <gui name="${name}" ${
        lib.optionalString (translationDomain != null) ''translationDomain="${translationDomain}"''
      } version="${toString version}">
        ${
          lib.optionalString (menubar != null) ''
            <MenuBar ${
              lib.optionalString (menubar.alreadyVisited != null) ''alreadyVisited="${menubar.alreadyVisited}"''
            }>
              ${
                lib.concatMapStringsSep "\n" (menu: ''
                  <Menu ${
                    lib.optionalString (menubar.alreadyVisited != null) ''alreadyVisited="${menubar.alreadyVisited}"''
                  } name="${menu.name}" ${
                    lib.optionalString (menubar.noMerge != null) ''noMerge="${menubar.noMerge}"''
                  }>
                    ${
                      lib.concatMapStringsSep "\n" (item: ''
                        ${generateItem item}
                      '') menu.items
                    }
                  </Menu>
                '') menubar.menus
              }
            </MenuBar>
          ''
        }
        ${
          lib.optionalString (toolbar != null) ''
            <ToolBar ${
              lib.optionalString (toolbar.alreadyVisited != null) ''alreadyVisited="${toolbar.alreadyVisited}"''
            } name="${toolbar.name}" ${
              lib.optionalString (toolbar.noMerge != null) ''noMerge="${toolbar.noMerge}"''
            }>
              ${lib.concatMapStringsSep "\n" (item: ''${generateItem item}'') toolbar.items}
            </ToolBar>
          ''
        }
        ${
          lib.optionalString (actionProperties != null) ''
            ${lib.concatMapStringsSep "\n" (actionProps: ''
              <ActionProperties scheme="${actionProps.scheme}">
                ${
                  lib.concatMapStringsSep "\n" (property: ''
                    ${generateActionProperty property}
                  '') actionProps.properties
                }
              </ActionProperties>
            '') actionProperties}
          ''
        }
      </gui>
    '';
in
{
  inherit generateKXMLGUI kxmlguiType;
}
