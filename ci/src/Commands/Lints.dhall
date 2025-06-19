let Base = ../Base.dhall

let Cmd = Base.Lib.Cmds

let Command = Base.Command.Base

let Size = Base.Command.Size.Type

let Images = ../Images.dhall

in  Command.build
      Command.Config::{
      , commands = [ Cmd.run "cd ci && make all" ]
      , label = "Lints: Dhall"
      , key = "lints-dhall"
      , target = Size.Multi
      }
