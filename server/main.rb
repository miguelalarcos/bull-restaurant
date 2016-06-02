$LOAD_PATH.unshift '../../bull-rb'
$LOAD_PATH.unshift '../../app'
require 'server/server'
require 'server/start'
require 'conf'
require 'bigdecimal'
require 'time'

class AppController < BullServerController

  def before_insert_line doc
    true
  end

  def before_update_line old, new, merged
    true
  end

  def after_insert_line doc
    puts 'after insert line'
  end

  def after_update_line doc
    puts 'after update line'
  end

  def before_delete_line doc
    true
  end

  def rpc_products #path
    #check path, String
    rmsync $r.table('product') #.filter(:path=>path)
  end

  def rpc_new_table waiter, table
    check waiter, String
    check table, String
    orders = rmsync $r.table('order').filter(:status=>'opened')
    tables = orders.collect{|x| x['table']}
    if tables.include? table
      nil
    else
      ret = rsync $r.table('order').insert(status: 'opened', waiter: waiter, table: table, timestamp: Time.now, total: 0.0)
      ret['generated_keys'][0]
    end
    #orders = rmsync $r.table('order').filter(:status=>'opened')
    #tables = orders.collect{|x| x['table'].to_i}.sort
    #new_table = 1
    #for table in tables
    #  if new_table != table
    #    break
    #  end
    #  new_table += 1
    #end
    #ret = rsync $r.table('order').insert(status: 'opened', waiter: waiter, table: new_table.to_s, datetime: Time.now, total: 0.0)
    #[ret['generated_keys'][0], new_table.to_s]
  end

  def task_send order_id
    check order_id, String
    rsync $r.table('line').filter(:order_id=>order_id, :status=>'draft', :scope=>'kitchen').update(:status=>'kitchen')
    rsync $r.table('line').filter(:order_id=>order_id, :status=>'draft', :scope=>'bar').update(:status=>'bar')
  end

  def task_kitchen_line_done line
    check line, String
    rsync $r.table('line').get(line).update(:status=>'kitchen_done')
  end

  def task_kitchen_done order_id
    check order_id, String
    rsync $r.table('line').filter(:order_id=>order_id, :status=>'kitchen').update(:status=>'kitchen_done')
  end

  def total order_id
    lines = rmsync $r.table('line').filter(:order_id=>order_id, :status=>'done')
    total = lines.inject(BigDecimal('0')){|sum, n| sum + BigDecimal(n['price'])*BigDecimal(n['quantity'])}
    rsync $r.table('order').get(order_id).update({:total=> total.to_f})
  end

  def task_bar_done order_id
    check order_id, String
    rsync $r.table('line').filter(:order_id=>order_id, :status=>'bar').update(:status=>'bar_done')
  end

  def task_done order_id, scope
    check order_id, String
    check scope, Sting
    rsync $r.table('line').filter(:order_id=>order_id, :status=>scope+'_done').update(:status=>'done')
    total order_id
  end

  def task_close_order order_id
    check order_id, String
    rsync $r.table('order').get(order_id).update({:status=> 'closed'})
  end

  def watch_waiter_notifications waiter
    check waiter, String
    $r.table('line').filter(:status=> 'kitchen_done', :waiter=>waiter)
  end

  def watch_tables_opened
    $r.table('order').filter(:status=>'opened')
  end

  def watch_order order_id
    check order_id, String
    if order_id.nil?
      nil
    else
      $r.table('order').get(order_id)
    end
  end

  def watch_table order_id
    check order_id, String
    $r.table('line').filter(:order_id=>order_id)
  end

  def watch_kitchen
    $r.table('line').filter(:status=>'kitchen')
  end

  def watch_bar
    $r.table('line').filter(:status=>'bar')
  end

end

start AppController