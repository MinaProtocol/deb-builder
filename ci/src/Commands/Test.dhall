let Base = ../Base.dhall

let Cmd = Base.Lib.Cmds

let Command = Base.Command.Base

let Size = Base.Command.Size.Type

let Images = ../Images.dhall

in  Command.build
      Command.Config::{
      , commands =
        [ Cmd.runInDocker
            Cmd.Docker::{ image = Images.containerImage, privileged = True }
            "./ci/scripts/test_app.sh"
        ]
      , label = "Test"
      , key = "test"
      , target = Size.Multi
      }
