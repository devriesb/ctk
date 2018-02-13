class Config
  def self.load
    conf                        = OpenStruct.new

    conf.user                   = 'root'
    conf.pass                   = 'cloudera'
    conf.hostnames              = (1..5).map{ |n| "jmichaels2-#{n}.gce.cloudera.com"}
    conf.mysql_root_pass        = 'VaT990mLJj'
    conf.mysql_slave_user_pass  = 'r47XkHCgpn'
    conf.mysql_cm_dbs_password  = 'h1TqkGM3TH'
    conf.mysql_replication_host = nil
    conf.debug_mode             = true

    conf.cm                     = OpenStruct.new

    conf.cm.host                = conf.hostnames[0]
    conf.cm.user                = 'admin'
    conf.cm.password            = 'admin'
    conf.cm.port                = 7180

    conf
  end
end
