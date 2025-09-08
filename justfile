flatpak_mods_dir := "~/.var/app/org.luanti.luanti/.minetest/mods"

# list recipes
default:
  @just --list

# optimize PNG textures
optimize-textures:
  ./tools/optimize-textures.nu

# copy a mod into the Luanti flatpak's mods directory
install-flatpak mod:
  mkdir --parents {{ flatpak_mods_dir }}
  rm --recursive --force {{ flatpak_mods_dir }}/{{ mod }}
  cp --recursive ./sounds/ ./textures/ ./mod.conf ./*.lua {{ flatpak_mods_dir }}/{{ mod }}
