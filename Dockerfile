# use the standard docker tomcat image as the base image for this image
FROM tomcat

MAINTAINER Lee Evans <levans@ohdsi.org>

# Install the WebAPI WAR file to the tomcat webapps directory
ADD WebAPI.war /usr/local/tomcat/webapps/

# Install the postgresql jdbc driver to the tomcat lib directory
ADD postgresql-9.3-1102.jdbc3.jar /usr/local/tomcat/lib/

# expose the standard tomcat port to the host
EXPOSE 8080

# Start the Tomcat web server (which will auto install the above WAR file)
CMD /usr/local/tomcat/bin/catalina.sh run
