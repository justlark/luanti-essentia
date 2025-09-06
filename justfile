flatpak_mods_dir := "~/.var/app/org.luanti.luanti/.minetest/mods"

# list recipes
default:
  @just --list

# run unit tests for a mod
test mod:
  cd ./mods/{{ mod }}/tests && ~/.luarocks/bin/busted .

# optimize PNG textures
optimize-textures:
  ./tools/optimize-textures.nu

# copy a mod into the Luanti flatpak's mods directory
install-flatpak mod:
  mkdir --parents {{ flatpak_mods_dir }}
  rm --recursive --force {{ flatpak_mods_dir }}/{{ mod }}
  cp --recursive ./mods/{{ mod }} {{ flatpak_mods_dir }}/{{ mod }}
