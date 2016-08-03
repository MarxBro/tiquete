#!/bin/bash
######################################################################
# Usar para iniciar tiquete
######################################################################

nohup plackup -E production -p 3456 bin/app.psgi &
exit 0
