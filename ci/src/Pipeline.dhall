let Base = ./Base.dhall

let Pipeline = Base.Pipeline.Type

let BuildAndSign = ./Commands/BuildAndSign.dhall

let Lints = ./Commands/Lints.dhall

let Test = ./Commands/Test.dhall

in  Pipeline.build [ BuildAndSign, Lints, Test ]
