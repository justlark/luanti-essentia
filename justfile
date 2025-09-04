# list recipes
default:
  @just --list

# optimize PNG textures
optimize-textures:
  ./tools/optimize-textures.nu
