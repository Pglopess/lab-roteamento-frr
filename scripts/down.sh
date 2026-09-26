#!/usr/bin/env bash
cd "$(dirname "$0")/.."
containerlab destroy -t topo.clab.yml --cleanup
