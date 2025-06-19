let Base = ./Base.dhall

let Cmd = Base.Lib.Cmds

let Pipeline = Base.Pipeline.Type

let Command = Base.Command.Base

let Size = Base.Command.Size.Type

let Images = ./Images.dhall

in  Pipeline.build
      [ Command.build
          Command.Config::{
          , commands =
            [ Cmd.runInDocker
                Cmd.Docker::{ image = Images.containerImage, privileged = True }
                "sudo chown -R opam . && cd ci && make all"
            ]
          , label = "Lints: Dhall"
          , key = "lints-dhall"
          , target = Size.Multi
          }
      ]
