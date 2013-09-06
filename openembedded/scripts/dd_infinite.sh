#!/bin/bash

while true; do dd if=/dev/zero of=bigfile bs=1024000 count=1024; done

