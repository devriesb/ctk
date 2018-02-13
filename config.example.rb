class Config
  def self.load
    conf                        = OpenStruct.new

    conf.user                   = 'root'
    conf.pass                   = 'xxxxxxx'
    conf.hostnames              = (1..5).map{ |n| "my-server-#{n}.wat.cloudera.com"}
    conf.mysql_root_pass        = 'xxxxxxxxxxx'
    conf.mysql_slave_user_pass  = 'xxxxxxxxxxx'
    conf.mysql_cm_dbs_password  = 'xxxxxxxxxxx'
    conf.mysql_replication_host = "my-server-2.wat.cloudera.com"
    conf.debug_mode             = true

    conf.cm                     = OpenStruct.new

    conf.cm.host                = conf.hostnames[0]
    conf.cm.user                = 'admin'
    conf.cm.password            = 'xxxxxxxxx'
    conf.cm.port                = 7180

    conf
  end
end
