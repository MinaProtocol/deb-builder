let Base = ./Base.dhall

let Cmd = Base.Lib.Cmds

let Pipeline = Base.Pipeline.Type

let DockerLogin = Base.Plugin.DockerLogin.Type

let Command = Base.Command.Base

let Size = Base.Command.Size.Type

let Images = ./Images.dhall

in  Pipeline.build
      [ Command.build
          Command.Config::{
          , commands =
            [ Cmd.runInDocker
                Cmd.Docker::{ image = Images.containerImage, privileged = True }
                "sudo chown -R opam . && ./ci/scripts/build_app.sh"
            , Cmd.run "./ci/scripts/build_docker.sh"
            , Cmd.runInDocker
                Cmd.Docker::{ image = Images.debianBuilderImage }
                "./ci/scripts/build_debian.sh"
            ]
          , label = "Build: Docker and Debian"
          , key = "build"
          , target = Size.Multi
          , docker_login = Some DockerLogin::{=}
          }
      , Command.build
          Command.Config::{
          , commands =
            [ Cmd.runInDocker
                Cmd.Docker::{ image = Images.containerImage, privileged = True }
                "sudo chown -R opam . && ./ci/scripts/test_app.sh"
            ]
          , label = "Test"
          , key = "test"
          , target = Size.Multi
          }
      ]
