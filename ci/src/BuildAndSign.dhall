let Base = ./Base.dhall

let Cmd = Base.Lib.Cmds

let Pipeline = Base.Pipeline.Type

let Command = Base.Command.Base

let Docker = Base.Plugin.Docker.Type

let Size = Base.Command.Size.Type

let containerImage =
      "gcr.io/o1labs-192920/mina-toolchain@sha256:8248ceb8f35bae0b5b0474a3e296ad0380ea2ab339f353943ee36564a12a745a"

in  Pipeline.build
      [ Command.build
          Command.Config::{
          , commands = [ Cmd.run "./ci/scripts/build_app.sh" ]
          , label = "App"
          , key = "build"
          , target = Size.Multi
          , docker = Some Docker::{ 
            , image = containerImage
            , user = Some "root" 
            }
          }
      , Command.build
          Command.Config::{
          , commands = [ Cmd.run "./ci/scripts/build_debian.sh" ]
          , label = "Debian Package"
          , key = "debian"
          , target = Size.Multi
          , depends = [ "build" ]
          , docker = Some Docker::{
            , image = "minaprotocol/mina-debian-builder:0.0.1-alpha1"
            , shell = None (List Text)
            }
          }
      , Command.build
          Command.Config::{
          , commands = [ Cmd.run "./ci/scripts/build_docker.sh" ]
          , label = "Docker Image"
          , depends = [ "debian" ]
          , key = "docker"
          , target = Size.Multi
          , docker = None Docker.Type
          }
      ]
