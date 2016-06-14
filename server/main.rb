$LOAD_PATH.unshift '../../bull-rb'
$LOAD_PATH.unshift '../../app'
require 'server/server'
require 'server/start'
require 'conf'
require 'bigdecimal'
require 'time'
require 'validation/validation-item'

class AppController < BullServerController

  def initialize ws, conn
    super ws, conn
    @sent_code = 0
  end

  def restaurante
    'restaurante-101'
    #@user_doc['restaurant']
  end

  def before_insert_item doc
    doc[:restaurant] = restaurante
    ValidateItem.validate doc
  end

  def before_update_item old, new, merged
    merged[:restaurant] = restaurante
    ValidateItem.validate merged
  end

  def rpc_items
    rmsync $r.table('item').filter({restaurant: restaurante})
  end

  def watch_items_by_pattern pattern
    if pattern.length >= 2
      $r.table('item').filter{|doc|
        doc['type'].eq('item') & doc['restaurant'].eq(restaurante) & doc['code'].match("(?i)#{pattern}")
      }
    end
  end

  def watch_groupers
    $r.table('item').filter({restaurant: restaurante, type: 'groupers'})
  end
end

start AppController