let Base = ./Base.dhall

let Cmd = Base.Lib.Cmds

let Pipeline = Base.Pipeline.Type

let Command = Base.Command.Base

let Docker = Base.Plugin.Docker.Type

let Size = Base.Command.Size.Type

in  Pipeline.build
      [ Command.build
          Command.Config::{
          , commands = [ Cmd.run "./ci/scripts/build_and_sign.sh" ]
          , label = "Build and Sign"
          , key = "build-and-sign"
          , target = Size.Multi
          , docker = Some Docker::{ image = "alpine:3.10" }
          }
      ]