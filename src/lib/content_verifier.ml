open Core
open Async
open Dolog

let or_from_defaults_file default_opt = function
  | None ->
      default_opt
  | Some value ->
      Some value

module Dpkg_Deb_Output = struct
  type t =
    { package_name : string
    ; version : string
    ; architecture : string
    ; vendor : string option
    ; package_authors : string option
    ; package_maintainer : string option
    ; package_description : string option
    ; package_section : string option
    ; package_priority : string option
    ; package_homepage : string option
    ; package_installed_size : string option
    ; package_source : string option
    ; suite : string option
    ; codename : string option
    ; depends : string list
    ; suggested_depends : string list
    ; recommended_depends : string list
    ; pre_depends : string list
    ; conflicts : string list
    ; replaces : string list
    ; provides : string list
    ; license : string option
    ; githash : string option
    ; buildurl : string option
    ; description : string
    }
  [@@deriving yojson]

  let from_str str =
    let lines = String.split ~on:'\n' str in
    let properties =
      List.map (List.drop lines 3) ~f:(fun line ->
          match String.split ~on:':' line with
          | [ name; value ] ->
              (name, value)
          | _ ->
              failwith "Wrong format" )
    in

    let description =
      List.fold lines ~init:("", false) ~f:(fun (acc, started) line ->
          if started then (acc ^ line, started)
          else if String.is_prefix ~prefix:"Description:" line then (acc, true)
          else (acc, started) )
      |> fst
    in

    let githash, buildurl =
      Scanf.sscanf description "Built from %s by %s" (fun githash buildurl ->
          (Some githash, Some buildurl) )
    in
    let property name =
      match List.Assoc.find properties ~equal:String.equal name with
      | Some value ->
          Some value
      | None ->
          None
    in
    let property_as_list name =
      match property name with
      | Some value ->
          String.split ~on:',' value
      | None ->
          []
    in
    { depends = property_as_list "Depends"
    ; suggested_depends = property_as_list "Suggests"
    ; recommended_depends = property_as_list "Recommends"
    ; pre_depends = property_as_list "Pre-Depends"
    ; conflicts = property_as_list "Conflicts"
    ; replaces = property_as_list "Replaces"
    ; provides = property_as_list "Provides"
    ; vendor = property "Vendor"
    ; package_authors = property "Authors"
    ; package_maintainer = property "Maintainer"
    ; package_description = property "Description"
    ; package_section = property "Section"
    ; package_priority = property "Priority"
    ; package_homepage = property "Homepage"
    ; package_installed_size = property "Installed-Size"
    ; package_source = property "Source"
    ; architecture =
        property "Architecture"
        |> Option.value_exn ~message:"Architecture not found"
    ; suite = property "Suite"
    ; codename = property "Codename"
    ; license = property "License"
    ; githash
    ; buildurl
    ; description
    ; package_name =
        property "Architecture" |> Option.value_exn ~message:"Package not found"
    ; version =
        property "Architecture" |> Option.value_exn ~message:"Version not found"
    }
end

let get_deb_output ~deb =
  let open Deferred.Or_error.Let_syntax in
  let%bind output = Process.run ~prog:"dpkg-deb" ~args:[ "-I"; deb ] () in
  return (Dpkg_Deb_Output.from_str output)

let verify ~deb ~defaults_file ~vendor ~package_authors ~package_maintainer
    ~package_description ~package_section ~package_priority ~package_homepage
    ~package_installed_size ~package_source ~architecture ~suite ~codename
    ~depends ~suggested_depends ~recommended_depends ~pre_depends ~conflicts
    ~replaces ~provides ~license ~githash ~buildurl =
  let open Deferred.Or_error.Let_syntax in
  let%bind defaults = Defaults.load defaults_file |> Deferred.return in

  let maybe_split = Option.map ~f:(String.split ~on:',') in

  let depends =
    Option.merge (maybe_split depends) defaults.depends ~f:(fun a b -> a @ b)
  in
  let suggested_depends =
    Option.merge (maybe_split suggested_depends) defaults.suggested_depends
      ~f:(fun a b -> a @ b )
  in
  let recommended_depends =
    Option.merge (maybe_split recommended_depends) defaults.recommended_depends
      ~f:(fun a b -> a @ b )
  in
  let pre_depends =
    Option.merge (maybe_split pre_depends) defaults.pre_depends ~f:(fun a b ->
        a @ b )
  in
  let conflicts =
    Option.merge (maybe_split conflicts) defaults.conflicts ~f:(fun a b ->
        a @ b )
  in
  let replaces =
    Option.merge (maybe_split replaces) defaults.replaces ~f:(fun a b -> a @ b)
  in
  let provides =
    Option.merge (maybe_split provides) defaults.provides ~f:(fun a b -> a @ b)
  in

  let vendor = or_from_defaults_file vendor defaults.vendor in
  let package_authors =
    or_from_defaults_file package_authors defaults.package_authors
  in
  let package_maintainer =
    or_from_defaults_file package_maintainer defaults.package_maintainer
  in
  let package_section =
    or_from_defaults_file package_section defaults.package_section
  in
  let package_priority =
    or_from_defaults_file package_priority defaults.package_priority
  in
  let package_homepage =
    or_from_defaults_file package_homepage defaults.package_homepage
  in
  let package_installed_size =
    or_from_defaults_file package_installed_size defaults.package_installed_size
  in
  let package_source =
    or_from_defaults_file package_source defaults.package_source
  in
  let architecture = or_from_defaults_file architecture defaults.architecture in
  let license = or_from_defaults_file license defaults.license in
  let githash = or_from_defaults_file githash defaults.githash in
  let buildurl = or_from_defaults_file buildurl defaults.buildurl in

  let open Deferred.Or_error.Let_syntax in
  let%bind deb_output = get_deb_output ~deb in
  Log.info "deb_output: %s\n"
    (Yojson.Safe.to_string (Dpkg_Deb_Output.to_yojson deb_output)) ;

  let check_optional_property (expected : string option)
      (actual : string option) ~(name : string) =
    match expected with
    | Some expected -> (
        match actual with
        | None ->
            Or_error.errorf "%s mismatch. Expected: %s, Actual: None" name
              expected
        | Some actual ->
            if String.equal expected actual then
              Or_error.errorf "%s mismatch. Expected: %s, Actual: %s" name
                expected actual
            else Ok () )
    | None ->
        Ok ()
  in

  let check_required_property (expected : string) (actual : string)
      ~(name : string) =
    if String.equal expected actual then
      Or_error.errorf "%s mismatch. Expected: %s, Actual: %s" name expected
        actual
    else Ok ()
  in

  let check_list_property (expected : string list option) (actual : string list)
      ~(name : string) =
    match expected with
    | Some expected ->
        let expected_set = Set.of_list (module String) expected in
        let actual_set = Set.of_list (module String) actual in
        let missing = Set.diff expected_set actual_set in
        if Set.is_empty missing then Ok ()
        else
          Or_error.errorf "%s mismatch. Missing: %s" name
            (String.concat ~sep:"," (Set.to_list missing))
    | None ->
        Ok ()
  in

  let list_to_tuple = function
    | [ a; b ] ->
        (a, b)
    | _ ->
        failwith "Expected a list with exactly two elements"
  in
  let package, version =
    Filename.basename deb |> String.split ~on:'_' |> list_to_tuple
  in

  let%bind () =
    check_required_property package deb_output.package_name ~name:"Package"
    |> Deferred.return
  in
  let%bind () =
    check_required_property version deb_output.version ~name:"Version"
    |> Deferred.return
  in
  let%bind () =
    check_optional_property architecture (Some deb_output.architecture)
      ~name:"Architecture"
    |> Deferred.return
  in
  let%bind () =
    check_optional_property deb_output.vendor vendor ~name:"Vendor"
    |> Deferred.return
  in
  let%bind () =
    check_optional_property package_authors deb_output.package_authors
      ~name:"Authors"
    |> Deferred.return
  in
  let%bind () =
    check_optional_property package_maintainer deb_output.package_maintainer
      ~name:"Maintainer"
    |> Deferred.return
  in
  let%bind () =
    check_optional_property package_description deb_output.package_description
      ~name:"Description"
    |> Deferred.return
  in
  let%bind () =
    check_optional_property package_section deb_output.package_section
      ~name:"Section"
    |> Deferred.return
  in
  let%bind () =
    check_optional_property package_priority deb_output.package_priority
      ~name:"Priority"
    |> Deferred.return
  in
  let%bind () =
    check_optional_property package_homepage deb_output.package_homepage
      ~name:"Homepage"
    |> Deferred.return
  in
  let%bind () =
    check_optional_property package_installed_size
      deb_output.package_installed_size ~name:"Installed-Size"
    |> Deferred.return
  in
  let%bind () =
    check_optional_property package_source deb_output.package_source
      ~name:"Source"
    |> Deferred.return
  in
  let%bind () =
    check_optional_property architecture (Some deb_output.architecture)
      ~name:"Architecture"
    |> Deferred.return
  in
  let%bind () =
    check_optional_property license deb_output.license ~name:"License"
    |> Deferred.return
  in
  let%bind () =
    check_optional_property githash deb_output.githash ~name:"Githash"
    |> Deferred.return
  in
  let%bind () =
    check_optional_property buildurl deb_output.buildurl ~name:"Buildurl"
    |> Deferred.return
  in
  let%bind () =
    check_optional_property suite deb_output.suite ~name:"Suite"
    |> Deferred.return
  in
  let%bind () =
    check_optional_property codename deb_output.codename ~name:"Codename"
    |> Deferred.return
  in
  let%bind () =
    check_list_property depends deb_output.depends ~name:"Depends"
    |> Deferred.return
  in
  let%bind () =
    check_list_property suggested_depends deb_output.suggested_depends
      ~name:"Suggests"
    |> Deferred.return
  in
  let%bind () =
    check_list_property recommended_depends deb_output.recommended_depends
      ~name:"Recommends"
    |> Deferred.return
  in
  let%bind () =
    check_list_property pre_depends deb_output.pre_depends ~name:"Pre-Depends"
    |> Deferred.return
  in
  let%bind () =
    check_list_property conflicts deb_output.conflicts ~name:"Conflicts"
    |> Deferred.return
  in
  let%bind () =
    check_list_property replaces deb_output.replaces ~name:"Replaces"
    |> Deferred.return
  in
  let%bind () =
    check_list_property provides deb_output.provides ~name:"Provides"
    |> Deferred.return
  in

  Deferred.Or_error.ok_unit
