open Jingoo

let as_str name value = (name, Jg_types.Tstr value)

let as_list values =
  List.map
    (fun (name, value) ->
      Jg_types.Tobj [ as_str "name" name; as_str "value" value ] )
    values

let policy_file_template =
  {|<?xml version="1.0"?>
<!DOCTYPE Policy SYSTEM "https://www.debian.org/debsig/1.0/policy.dtd">
<Policy xmlns="https://www.debian.org/debsig/1.0/">

  <!-- Here name and description can be anything. -->
  <Origin Name="Verification" id="{{ key_id }}" Description="{{ description }}" />

  <Selection>
    <Required Type="origin" File="{{ key_filename }}" id="{{ key_id }}"/>
  </Selection>

  <Verification MinOptional="0">
    <Required Type="origin" File="{{ key_filename }}" id="{{ key_id }}"/>
  </Verification>

</Policy>
|}

type policy_file_input =
  { key_filename : string; key_id : string; description : string }

let format_policy_file ~input =
  Jg_template.from_string policy_file_template
    ~models:
      [ as_str "key_filename" input.key_filename
      ; as_str "key_id" input.key_id
      ; as_str "description" input.description
      ]

let debian_control_file_template =
  {|
{%- autoescape false -%}
{% for property in properties %}{{ property.name }}: {{ property.value }}
{% endfor %}Description:
 {{ description }}
 Built from {{ githash }} by {{ buildurl }}
{% endautoescape -%}
|}

type debian_control =
  { package_name : string
  ; version : string
  ; vendor : string
  ; package_authors : string
  ; package_maintainer : string
  ; package_description : string
  ; package_section : string
  ; package_priority : string
  ; package_homepage : string
  ; package_installed_size : string
  ; package_source : string
  ; architecture : string
  ; suite : string
  ; codename : string
  ; depends : string list option
  ; suggested_depends : string list option
  ; recommended_depends : string list option
  ; pre_depends : string list option
  ; conflicts : string list option
  ; replaces : string list option
  ; provides : string list option
  ; license : string
  ; githash : string
  ; buildurl : string
  }

let format_control_file (input : debian_control) =
  Jg_template.from_string debian_control_file_template
    ~models:
      [ as_str "description" input.package_description
      ; as_str "githash" input.githash
      ; as_str "buildurl" input.buildurl
      ; ( "properties"
        , Jg_types.Tlist
            (as_list
               [ ("Package", input.package_name)
               ; ("Version", input.version)
               ; ("Architecture", input.architecture)
               ; ("Maintainer", input.package_maintainer)
               ; ("Section", input.package_section)
               ; ("Priority", input.package_priority)
               ; ("Homepage", input.package_homepage)
               ; ("Installed-Size", input.package_installed_size)
               ; ("Source", input.package_source)
               ; ("Suite", input.suite)
               ; ("Codename", input.codename)
               ; ("License", input.license)
               ] ) )
      ]
