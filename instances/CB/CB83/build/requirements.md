# Build requirements

Use the official `ubuntu:22.04` image and install Apache HTTP Server, nginx, and curl from the Ubuntu repositories. Configure Apache to serve the test page on port 8080 and nginx to listen on port 80 and proxy normal requests to Apache. The fault overlay adds one additional global Apache `Listen 80` declaration, competing with nginx's port 80 listener. Do not copy harnesses, metadata, or the public prompt into the image.
