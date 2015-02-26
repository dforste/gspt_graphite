# Class: gspt_graphite
#
# This module manages gspt_graphite
#
# Parameters: none
#
# Actions:
#
# Requires: see Modulefile
#
# Sample Usage:
#
class gspt_graphite {
  include '::apache'

  apache::vhost { "graphite-web${::fqdn}":
    port    => '80',
    docroot => '/opt/graphite/webapp',
    wsgi_application_group      => '%{GLOBAL}',
    wsgi_daemon_process         => 'graphite',
    wsgi_daemon_process_options => {
      processes          => '5',
      threads            => '5',
      display-name       => '%{GROUP}',
      inactivity-timeout => '120',
    },
    wsgi_import_script          => '/opt/graphite/conf/graphite.wsgi',
    wsgi_import_script_options  => {
      process-group     => 'graphite',
      application-group => '%{GLOBAL}'
    },
    wsgi_process_group          => 'graphite',
    wsgi_script_aliases         => {
      '/' => '/opt/graphite/conf/graphite.wsgi'
    },
    headers => [
      'set Access-Control-Allow-Origin "*"',
      'set Access-Control-Allow-Methods "GET, OPTIONS, POST"',
      'set Access-Control-Allow-Headers "origin, authorization, accept"',
    ],
    directories => [{
      path => '/media/',
      order => 'deny,allow',
      allow => 'from all'}
    ]
  }
  class { 'graphite':
    gr_web_server => 'none'
  }
  
  apache::vhost { "grafana.${::fqdn}":
    servername      => $::fqdn,
    port            => 80,
    docroot         => '/opt/grafana',
    error_log_file  => 'grafana_error.log',
    access_log_file => 'grafana_access.log',
    directories     => [
      {
        path            => '/opt/grafana',
        options         => [ 'None' ],
        allow           => 'from All',
        allow_override  => [ 'None' ],
        order           => 'Allow,Deny',
      }
    ]
  }->
  class {'grafana':
#    datasources  => {
#      'graphite' => {
#        'type'    => 'graphite',
#        'url'     => $::fqdn, 
#        'default' => 'true'
#      },
#      'elasticsearch' => {
#        'type'      => 'elasticsearch',
#        'url'       => $::fqdn
#        'index'     => 'grafana-dash',
#        'grafanaDB' => 'true',
#      },
  graphite_host      => $::fqdn,
  elasticsearch_host => $::fqdn,
  elasticsearch_port => 9200,
  }
  
  include java
  
  class { 'elasticsearch':
    manage_repo  => true,
    repo_version => '1.4',
    config       => {
      # Allow cross-origin resource sharing, i.e. whether a browser on another origin can do requests to Elasticsearch.
      # Remove if we end up doing proxy requests I think. . .
      # http://www.elasticsearch.org/guide/en/elasticsearch/reference/current/modules-http.html
      "http.cors.enabled" => "true"
      # Currently * origins can make requests should lock this down, regex is supported:
      # http.cors.allow-origin => /http?:\/\/localhost(:[0-9]+)?/
    }
  }
  elasticsearch::instance { 'es-01': }
}
