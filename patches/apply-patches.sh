#!/bin/bash
# Aplica los parches del C660 sobre un árbol CM7 limpio.
# Ejecutar desde la raíz del árbol de CM7.
#
#   cd /path/to/cm7
#   bash device/lge/c660/patches/apply-patches.sh

set -e

PATCHES_DIR="$(dirname "$0")"
CM7_ROOT="$(pwd)"

apply() {
    local project="$1"
    local patch="$2"
    echo "  Aplicando $patch en $project..."
    (cd "$CM7_ROOT/$project" && git apply "$CM7_ROOT/$PATCHES_DIR/$patch")
}

# frameworks/base — Bluetooth: un solo StopDiscovery al terminar el scan.
# El segundo, reentrante, no tiene sesión y BlueZ responde
# "Invalid discovery session".
apply frameworks/base frameworks_base_bluetooth.patch

# system/core — initlogo: el fb del C660 es 240 px con stride 512.
# Escribir las filas pegadas corre las letras 16 px por línea.
apply system/core system_core_init_logo.patch

# frameworks/base — telefonía: una SIM con bloqueo de red (PH-NET) llega con
# app_state SUBSCRIPTION_PERSO; sin este caso el radio state quedaba en
# SIM_NOT_READY y gsm.sim.state salía UNKNOWN en vez de NETWORK_LOCKED.
apply frameworks/base frameworks_base_sim_perso.patch
