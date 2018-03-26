class Config
  def self.load
    conf                        = OpenStruct.new
    conf.cm                     = OpenStruct.new

    # SSH credentials for your cluster nodes.
    # Currently, this must be the root user, and the password must be
    # the same on every server.
    conf.user                   = 'root'
    conf.pass                   = 'xxxxxxx'

    # You can programmatically build out the list of hostnames like:
    # 
    # conf.hostnames              = (1..5).map{ |n| "my-server-#{n}.wat.cloudera.com"}
    #
    # Or, you can simply list them in an array:
    conf.hostnames              = [
      "my-server-1.gce.cloudera.com",
      "my-server-2.gce.cloudera.com",
      "my-server-3.gce.cloudera.com",
      "my-server-4.gce.cloudera.com",
    ]
                                  
    # Choose a password to set for your MySQL root user
    conf.mysql_root_pass        = 'xxxxxxxxxxx'
 
    # Choose a password to set for your MySQL replication slave user
    conf.mysql_slave_user_pass  = 'xxxxxxxxxxx'

    # Choose a password to use for the MySQL databases managed by Cloudera Manager
    conf.mysql_cm_dbs_password  = 'xxxxxxxxxxx'

    # If you want to enable MySQL replication, enter the hostname of the server that
    # will host the MySQL replication instance like this:
    # 
    # conf.mysql_replication_host = "my-server-2.wat.cloudera.com"
    #
    # Otherwise, leave it `nil` and replication will not be set up.
    conf.mysql_replication_host = nil
    conf.debug_mode             = true

    # The server on which Cloudera Manager will be installed.
    # By default, we just use the first server.
    conf.cm.host                = conf.hostnames[0]
    conf.cm.user                = 'admin'
    conf.cm.password            = 'xxxxxxxxx'
    conf.cm.port                = 7180

    conf
  end
end
