let Base = ./Base.dhall

let Cmd = Base.Lib.Cmds

let Pipeline = Base.Pipeline.Type

let DockerLogin = Base.Plugin.DockerLogin.Type

let Command = Base.Command.Base

let Size = Base.Command.Size.Type

let containerImage =
      "gcr.io/o1labs-192920/mina-toolchain@sha256:8248ceb8f35bae0b5b0474a3e296ad0380ea2ab339f353943ee36564a12a745a"

in  Pipeline.build
      [ Command.build
          Command.Config::{
          , commands =
            [ Cmd.runInDocker
                Cmd.Docker::{ image = containerImage, privileged = True }
                "sudo chown -R opam . && ./ci/scripts/build_app.sh"
            , Cmd.run "./ci/scripts/build_docker.sh"
            , Cmd.runInDocker
                Cmd.Docker::{
                , image = "minaprotocol/mina-debian-builder:0.0.1-alpha1_7344965"
                }
                "./ci/scripts/build_debian.sh"
            ]
          , label = "App"
          , key = "build"
          , target = Size.Multi
          , docker_login = Some DockerLogin::{=}
          }
      ]
