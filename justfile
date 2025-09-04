# list recipes
default:
  @just --list

# optimize PNG textures
optimize-textures:
  ./tools/optimize-textures.nu

# copy a mod into the Luanti flatpak's mods directory
install-flatpak mod:
  mkdir -p ~/.var/app/org.luanti.luanti/.minetest/mods/
  cp -r ./mods/{{ mod }} ~/.var/app/org.luanti.luanti/.minetest/mods/{{ mod }}
