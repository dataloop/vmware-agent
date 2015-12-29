# Set up build variables
__CONTAINER_NAME=build-dataloop-vmware
__CONTAINER_IMAGE=dataloop/vmware-agent
__CONTAINER_SRC=phusion/baseimage
__CONTAINER_SCRIPT=/docker/build.sh

set -ev

# Clean up old build
docker rm -f ${__CONTAINER_NAME} || true

# Clean up old image
docker rmi ${__CONTAINER_IMAGE} || true 

# Run the build inside of docker
docker run -it \
	--name=${__CONTAINER_NAME} \
	-v $(pwd):/docker \
	${__CONTAINER_SRC} \
	${__CONTAINER_SCRIPT}

# Save the image
docker commit \
	${__CONTAINER_NAME} \
	${__CONTAINER_IMAGE}

