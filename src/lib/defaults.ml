open Core
open Dolog

type t =
  { vendor : string option [@default None]
  ; license : string option [@default None]
  ; package_authors : string option [@default None]
  ; package_maintainer : string option [@default None]
  ; package_description : string option [@default None]
  ; package_section : string option [@default None]
  ; package_priority : string option [@default None]
  ; package_homepage : string option [@default None]
  ; package_installed_size : string option [@default None]
  ; package_source : string option [@default None]
  ; architecture : string option [@default None]
  ; depends : string list option [@default None]
  ; suggested_depends : string list option [@default None]
  ; recommended_depends : string list option [@default None]
  ; pre_depends : string list option [@default None]
  ; conflicts : string list option [@default None]
  ; replaces : string list option [@default None]
  ; provides : string list option [@default None]
  ; githash : string option [@default None]
  ; buildurl : string option [@default None]
  }
[@@deriving yojson]

let load = function
  | None ->
      Ok
        { vendor = None
        ; package_authors = None
        ; package_maintainer = None
        ; package_description = None
        ; package_section = None
        ; package_priority = None
        ; package_homepage = None
        ; package_installed_size = None
        ; package_source = None
        ; architecture = None
        ; depends = None
        ; suggested_depends = None
        ; recommended_depends = None
        ; pre_depends = None
        ; conflicts = None
        ; replaces = None
        ; provides = None
        ; license = None
        ; githash = None
        ; buildurl = None
        }
  | Some file -> (
      match Sys_unix.file_exists file with
      | `Yes -> (
          let () = Log.info "Loading defaults from %s ...\n" file in
          match Yojson.Safe.from_file file |> of_yojson with
          | Ok defaults ->
              Ok defaults
          | Error msg ->
              Or_error.errorf "Wrong format of defaults file. %s " msg )
      | _ ->
          Or_error.errorf "File (%s) does not exist or permission denied" file )
