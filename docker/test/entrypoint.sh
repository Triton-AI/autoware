#!/bin/bash
# Setup your environment here, if any specific initialization is needed
# For example, source ROS2 workspace or any other dependencies

# Execute the ROS2 launch command
echo "ANANNIIII..."
# source "/opt/ros/$ROS_DISTRO/setup.bash"
source /autoware/install/setup.bash
echo "STARTING.."
exec "$@"