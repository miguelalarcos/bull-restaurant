$LOAD_PATH.unshift '../../bull-rb'
$LOAD_PATH.unshift '../../app'
require 'server/server'
require 'server/start'
require 'conf'
require 'bigdecimal'
require 'time'
require 'validation/validation-item'

class AppController < BullServerController

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
    $r.table('item').filter({restaurant: restaurante, type: 'grouper'})
  end

  def before_insert_order doc
    doc[:restaurant] = restaurante
    doc[:timestamp] = Time.now
    doc[:total] = 0.0
    true
  end

  def before_insert_line doc
    doc[:restaurant] = restaurante
    true
  end

  def after_insert_line doc
    price = doc[:price]
    order_id = doc[:order_id]
    rsync $r.table('order').get(order_id).update do |order|
      {:total => order['total'] + price}
    end
  end

  def before_delete_line doc
    true
  end

  def after_delete_line doc
    price = doc[:price]
    order_id = doc[:order_id]
    rsync $r.table('order').get(order_id).update do |order|
      {:total => order['total'] - price}
    end
  end

  def watch_tables
    $r.table('order').filter({restaurant: restaurante, active: true})
  end

  #def get_order_from_table table
  #  check table, String
  #  doc = get_unique $r.table('order').filter({restaurant: restaurante, active: true, table: table})
  #  if doc.nil?
  #    ret = rsync $r.table('order').insert({restaurant: restaurante, active: true, table: table, timestamp: Time.now})
  #    ret['generated_keys'][0]
  #  else
  #    doc[:id]
  #  end
  #end

  def watch_table_draft order_id
    check order_id, String
    $r.table('line').filter({restaurant: restaurante, status: 'draft', order_id: order_id})
  end
end

start AppController