#!/bin/bash

# Enable error checking
set -ev

# Update
apt-get update
apt-get -y dist-upgrade

# Install generally useful stuff
apt-get -y install \
	vim \
	curl \
	python-software-properties \
	openssh-client

# Install ruby PPA
apt-add-repository -y \
	ppa:brightbox/ruby-ng

# Install git PPA
apt-add-repository -y \
	ppa:git-core/ppa

# Update apt cache
apt-get update

# Install PPA based packages
apt-get -y install \
	ruby2.2 \
	git-core

# Import the apt repository gpg key
curl -s https://download.dataloop.io/pubkey.gpg | apt-key add -

# Add the Dataloop apt repository
echo 'deb https://download.dataloop.io/deb/ stable main' > /etc/apt/sources.list.d/dataloop.list

# Install the dataloop agent
apt-get update && sudo apt-get install dataloop-agent

# Install the required ruby gems (and deps)
apt-get -y install \
	build-essential \
	ruby2.2-dev \
	libxml2 \
	libxml2-dev \
	zlib1g-dev

gem install --no-document rbvmomi

# Remove build / compile tools
apt-get -y remove \
	build-essential \
	ruby2.2-dev \
	libxml2-dev \
	zlib1g-dev

# Cleanup
apt-get -y autoremove
apt-get clean
