############################################################### INSTALLING SYSTEM #############################################################

<<<<<<< HEAD
#Step 1: Install a fresh ubuntu 14.04 Trusty Tahr
=======
#Step 1: Install a fresh ubuntu 14.04
>>>>>>> 186f3f3439f8b4525eaa57abe6355d378a2944f1

#step 2: Change user to root user
	sudo su

#Step 3: Update your system
	apt-get update

############################################################### SETTING UP SYSTEM #############################################################

#Step 4: Installing the OpenStack Packages
	echo "Enabling the OpenStack repository"
	apt-get install -y ubuntu-cloud-keyring
	echo "deb http://ubuntu-cloud.archive.canonical.com/ubuntu" "trusty-updates/juno main" > /etc/apt/sources.list.d/cloudarchive-juno.list
	echo "Updating the system"
	apt-get update
    echo "Exporting the variables"
    source ./environment/variables.sh

#Step 5: Install and configure the Database
    echo "Installing the database and setting up the password"
	echo mysql-server mysql-server/root_password password $MYSQL_DBPASS | sudo debconf-set-selections
    echo mysql-server mysql-server/root_password_again password $MYSQL_DBPASS | sudo debconf-set-selections
	apt-get install -y mariadb-server python-mysqldb
    echo "configure the database server"
    rm -f /etc/mysql/my.cnf
	cp ./config/my.cnf /etc/mysql/
    service mysql restart

#Step 6: Install and Configure the RabbitMQ message broker service
    echo "Installing the RabbitMQ and setting up the password"
    apt-get install -y rabbitmq-server
    rabbitmqctl change_password guest $RABBIT_PASS

############################################################ IDENTITY SERVICE #################################################################

#Step 7: Add the Identity Service
    echo "Create a Database for the Identity service and granting permissions"
    mysql -u root -p$MYSQL_DBPASS << EOF
    CREATE DATABASE keystone;
    GRANT ALL PRIVILEGES ON keystone.* TO 'keystone'@'localhost' IDENTIFIED BY '$KEYSTONE_DBPASS';
    GRANT ALL PRIVILEGES ON keystone.* TO 'keystone'@'%' IDENTIFIED BY '$KEYSTONE_DBPASS'; 
EOF

#Step 8: Installing and Configuring the Identity Service
    echo "Install the Identity Service"
    apt-get install -y keystone python-keystoneclient
    echo "Configure Keystone"
    rm -f /etc/keystone/keystone.conf
    cp ./config/keystone.conf /etc/keystone/
	sed -e "/^connection =.*$/s/^.*$/connection = mysql:\/\/keystone:$KEYSTONE_DBPASS@127.0.0.1\/keystone/" -i /etc/keystone/keystone.conf
	sed -e "/^admin_token =.*$/s/^.*$/admin_token = $SERVICE_TOKEN" -i /etc/keystone/keystone.conf
    echo "Populate the Identity service database"
    su -s /bin/sh -c "keystone-manage db_sync" keystone

#Step 9: finalize Keystone installation
    echo "Restart the Identity service"
    service keystone restart
    rm -f /var/lib/keystone/keystone.db
    (crontab -l -u keystone 2>&1 | grep -q token_flush) || echo '@hourly /usr/bin/keystone-manage token_flush >/var/log/keystone/keystone-tokenflush.log 2>&1' >> /var/spool/cron/crontabs/keystone

#Step 10: Create tenants, users, and roles
    echo "Configuring the administration token"
    export OS_SERVICE_TOKEN=$SERVICE_TOKEN
    echo "Configuring the endpoint"
    export OS_SERVICE_ENDPOINT=http://127.0.0.1:35357/v2.0

    echo "ADMIN TENANT, USER AND ROLE"
    echo "Creating the admin tenant"
    keystone tenant-create --name admin --description "Admin Tenant"
    echo "Creating the admin user"
    keystone user-create --name admin --pass $ADMIN_PASS --email $ADMIN_EMAIL
    echo "Creating admin role"
    keystone role-create --name admin
    echo "Adding the role to admin"
    keystone user-role-add --tenant admin --user admin --role admin

    echo "Creating the _member_ role"
    keystone role-create --name _member_
    echo "Adding admin to _member_ role"
    keystone user-role-add --tenant admin --user admin --role _member_

    echo "Creating the demo tenant"
    keystone tenant-create --name demo --description "Demo Tenant"
    echo "Creating the demo user"
    keystone user-create --name demo --pass $DEMO_PASS --email $DEMO_EMAIL
    echo "Creating the _member_ role"
    keystone user-role-add --tenant demo --user demo --role _member_

    echo "Creating the service tenant"
    keystone tenant-create --name service --description "Service Tenant"
   

#Step 11: Create the Identity service entity and API endpoint
    echo "Creating the Identity Service"
    keystone service-create --name keystone --type identity --description "OpenStack Identity Service"
    echo "Creating the API endpoint for the Identity service"
    keystone endpoint-create --service-id $(keystone service-list | awk '/ identity / {print $2}') --publicurl http://127.0.0.1:5000/v2.0 --internalurl http://127.0.0.1:5000/v2.0 --adminurl http://127.0.0.1:35357/v2.0 --region regionOne

############################################################ IMAGE SERVICE ################################################################

#Step 12: Add the Image Service
    echo "Create a Database for the Image service and granting permissions"
    mysql -u root -p$MYSQL_DBPASS << EOF
    CREATE DATABASE glance;
    GRANT ALL PRIVILEGES ON glance.* TO 'glance'@'localhost' IDENTIFIED BY '$GLANCE_DBPASS';
    GRANT ALL PRIVILEGES ON glance.* TO 'glance'@'%' IDENTIFIED BY '$GLANCE_DBPASS'; 
EOF

    echo "gain admin credentials"
    source ./environment/admin-openrc.sh

#Step 13: creating the Identity service credentials
    echo "Create the glance user"
    keystone user-create --name glance --pass $GLANCE_DBPASS
    echo "Link the glance user to the service tenant and admin role"
    keystone user-role-add --user glance --tenant service --role admin

#Step 14: Create the Image service entity and API endpoint
    echo "Creating the Image Service"
    keystone service-create --name glance --type image --description "OpenStack Image Service"
    echo "Creating the API endpoint for the Image service"
    keystone endpoint-create --service-id $(keystone service-list | awk '/ image / {print $2}') --publicurl http://127.0.0.1:9292/v2.0 --internalurl http://127.0.0.1:9292/v2.0 --adminurl http://127.0.0.1:9292/v2.0 --region regionOne

#Step 15: Install and Configure the Image Service components
    echo "Installing Image Service"
    apt-get install -y glance python-glanceclient
    echo "Configuring Image Service"
    rm -f /etc/glance/glance-api.conf
    cp ./config/glance-api.conf /etc/glance/
	
    rm -f /etc/glance/glance-registry.conf
    cp ./config/glance-registry.conf /etc/glance/
	sed -e "/^connection =.*$/s/^.*$/connection = mysql:\/\/glance:$GLANCE_DBPASS@127.0.0.1\/glance" -i /etc/glance/glance-api.conf
	sed -e "/^admin_password =.*$/s/^.$/admin_password = $GLANCE_DBPASS" -i /etc/glance/glance-api.conf
    
	sed -e "/^connection =.*$/s/^.*$/connection = mysql:\/\/glance:$GLANCE_DBPASS@127.0.0.1\/glance" -i /etc/glance/glance-registry.conf
	sed -e "/^admin_password =.*$/s/^.$/admin_password = $GLANCE_DBPASS" -i /etc/glance/glance-registry.conf

    echo "Populate the Image Service database"
    su -s /bin/sh -c "glance-manage db_sync" glance

#Step 16: Finalize installation
    echo "Restart the Image Service services"
    service glance-registry restart
    service glance-api restart
    echo "Remove the SQLite database"
    rm -f /var/lib/glance/glance.sqlite

    echo "Upload an Ubuntu image"
    glance image-create --name "Ubuntu-14.04" --file ubuntu.img --disk-format qcow2 --container-format bare --is-public True --progress

########################################################## COMPUTE SERVICE ################################################################

#Step 17: Add the Nova Service
    echo "Create a Database for the Compute service and granting permissions"
	mysql -u root -p$MYSQL_DBPASS <<EOF
	create database nova;
	GRANT ALL PRIVILEGES ON nova.* TO 'nova'@'localhost' IDENTIFIED BY '$NOVA_DBPASS';
	GRANT ALL PRIVILEGES ON nova.* TO 'nova'@'%' IDENTIFIED BY '$NOVA_DBPASS';
	EOF

	echo "Getting admin credentials"
	source ./environment/admin-openrc.sh

#Step 18: creating the Identity service credentials
    echo "Create the glance user"
    keystone user-create --name nova --pass $NOVA_DBPASS
    echo "Link the glance user to the service tenant and admin role"
    keystone user-role-add --user nova --tenant service --role admin

#Step 19: Create the Image service entity and API endpoint
    echo "Creating the Image Service"
    keystone service-create --name nova --type compute --description "OpenStack Compute Service"
    echo "Creating the API endpoint for the Image service"
    keystone endpoint-create --service-id $(keystone service-list | awk '/ compute / {print $2}') --publicurl http://127.0.0.1:8774/v2/%\(tenant_id\)s --internalurl http://127.0.0.1:8774/v2/%\(tenant_id\)s --adminurl http://127.0.0.1:8774/v2/%\(tenant_id\)s --region regionOne

#Step 20: Install and Configure the Image Service components
    echo "Installing Compute Service"
	apt-get install -y nova-api nova-cert nova-conductor nova-consoleauth nova-novncproxy nova-scheduler python-novaclient
    echo "Configuring Compute Service"
    rm -f /etc/nova/nova.conf
    cp ./config/nova.conf /etc/nova/
	sed -e "/^connection =.*$/s/^.*$/connection = mysql:\/\/nova:$NOVA_DBPASS@127.0.0.1\/nova" -i /etc/nova/nova.conf
	sed -e "/^rabbit_password =.*$/s/^.$/rabbit_password = $RABBIT_PASS" -i /etc/nova/nova.conf
	sed -e "/^admin_password =.*$/s/^.$/admin_password = $NOVA_DBPASS" -i /etc/nova/nova.conf
    echo "Populate the Compute Service database"
    su -s /bin/sh -c "nova-manage db sync" nova

#Step 21: Finalize Installation
    echo "Restarting nova services"	
	service nova-api restart
	service nova-cert restart
	service nova-consoleauth restart
	service nova-scheduler restart
	service nova-conductor restart
	service nova-novncproxy restart

    echo "Remove the SQLite database"
	rm -rf /var/lib/nova/nova.sqlite

#Step 22: Install and Configure the Compute hypervisor components and restating compute services 
	echo "Installing nova hypervisor components"
	apt-get install -y nova-compute sysfsutils

    echo "Restarting nova-compute services"	
	service nova-compute restart

    echo "Remove the SQLite database"
	rm -f /var/lib/nova/nova.sqlite

############################################################ NETWORK SERVICE ##############################################################

#Step 23: Restarting some of nova services
	service nova-api restart
	service nova-scheduler restart
	service nova-conductor restart

#Step 24: Installing nova network components
	echo "Installing nova networking components"
	apt-get install -y nova-network nova-api-metadata
	sed -e "/^flat_interface =.*$/s/^.$/flat_interface = $INTERFACE_NAME" -i /etc/nova/nova.conf
	sed -e "/^public_interface =.*$/s/^.$/public_interface = $INTERFACE_NAME" -i /etc/nova/nova.conf
	service nova-network restart
	service nova-api-metadata restart

#Step 25: Reinstall nova-api service
	apt-get install -y nova-api

#Step 26: Gaining admin credentials and creating nova network 
	source ./environment/admin-openrc.sh
	nova network-create demo-net --bridge br100 --fixed-range-v4 $NETWORK_CIDR

############################################################ DASHBOARD ##############################################################

<<<<<<< HEAD
#Step 27 : Installing Openstack Dashboard horizon, and apache to host dashboard
	apt-get install -y openstack-dashboard apache2 libapache2-mod-wsgi memcached python-memcache
	rm -rf /etc/openstack-dashboard/local_settings.py
	cp local_settings.py /etc/openstack-dashboard/

#Step 28 : Restarting services 
	service apache2 restart
	service memcached restart

echo "##################################################################################################################################################
"
echo 
"#####                                                   openning Dashboard Component ie. Horizon                                             ####
"
echo "##################################################################################################################################################
"
	/usr/bin/firefox http://127.0.0.1/horizon
=======
#Step 27: Installing Openstack Dashboard horizon, and apache to host dashboard
	apt-get install -y openstack-dashboard apache2 libapache2-mod-wsgi memcached python-memcache

>>>>>>> 186f3f3439f8b4525eaa57abe6355d378a2944f1
