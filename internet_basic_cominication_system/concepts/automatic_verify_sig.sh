#!/bin/bash

#teste.pub está em ascii
gpg --import teste.pub
gpg --verify --default-key teste to-do.list.gpg
gpg --delete-keys --batch --yes teste