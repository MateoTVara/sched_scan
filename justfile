default:
  @just --list


alias a := add
alias b := build
alias c := check
alias f := format
alias s := sync-lock


[group('lock')]
sync-lock:
  yj -i < ./pubspec.lock > ./pubspec.lock.json



[group('dev')]
add package: sync-lock
  flutter pub add {{package}}
  just sync-lock

[group('dev')]
format:
  nix fmt

[group('dev')]
check: sync-lock
  nix flake -L check



[group('build')]
build package="linux": sync-lock
  nix build .#{{package}}
