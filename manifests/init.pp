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
    port    => '8080',
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
    gr_web_server     => 'none',
    secret_key        => '2WCT7as73gyP',
    gr_enable_carbon_relay => true,
    gr_relay_rules => {
      all       => { 
        pattern      => '.*',
        destinations => [ '127.0.0.1:2004' ] 
      },
      'default' => { 
        'default'    => true,
        destinations => [ '127.0.0.1:2004:a' ] 
      },
    },
    
    gr_enable_carbon_aggregator => true
    gr_aggregator_line_port => 
    gr_aggregator_destinations => []
    gr_aggregator_enable_udp_listener => true,
    
    aggregator_rules => {
      '00_min'         => { pattern => '\.min$',   factor => '0.1', method => 'min' },
      '01_max'         => { pattern => '\.max$',   factor => '0.1', method => 'max' },
      '02_sum'         => { pattern => '\.count$', factor => '0.1', method => 'sum' },
      '99_default_avg' => { pattern => '.*',       factor => '0.5', method => 'average'}
    },
    
    
    gr_line_receiver_port => 2103,
    gr_pickle_receiver_port => 2104, 
    gr_cache_query_port => 7102,
    gr_cache_instances => {
      'cache:b' => {
        'LINE_RECEIVER_PORT' => 2203,
        'PICKLE_RECEIVER_PORT' => 2204,
        'CACHE_QUERY_PORT' => 7202,
      },
      'cache:c' => {
        'LINE_RECEIVER_PORT' => 2303,
        'PICKLE_RECEIVER_PORT' => 2304,
        'CACHE_QUERY_PORT' => 7302,
      }
    }
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
    graphite_host      => $::fqdn,
    graphite_port      => 8080,
    elasticsearch_host => $::fqdn,
    elasticsearch_port => 9200,
  }
  
  class { 'java: 
    version_hash => { 
      'jdk1.8.0_31' => {
        install_jce => false, 
      }
    }
  }

  class { 'elasticsearch':
    manage_repo  => true,
    repo_version => '1.4',
    init_defaults => { 'JAVA_HOME' => '/opt/java/' }
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
