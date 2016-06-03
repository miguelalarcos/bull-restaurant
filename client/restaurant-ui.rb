def display item
  $items[item]['display']
end

def items item
  $items[item]['items']
end

def tree? item
  !$items[item]['items'].nil?
end

def complements item
  compl = $items[item]['complements']
  $items[compl] || []
end

def price item
  $items[item]['price']
end

def steps item
  $items[item]['steps']
end

def scope item
  $items[item]['scope']
end

# ###

class MainTab < React::Component::Base
  param :order_id
  param :table

  before_mount do
    clear
  end

  def clear
    state.line_id! nil
    state.menu_id! nil
    state.line_id! nil
    state.step! 'menu'
    state.type! 'carta'
  end

  def set_item
    lambda do |item|
      $controller.insert('line', {table: params.table, order_id: params.order_id, item: item, price: price(item), carta: true,
                                  display: display(item), timestamp: Time.now, status: 'draft', scope: scope(item)}).then do |line_id|
        state.line_id! line_id
      end
    end
  end

  def set_complements
    lambda do |complements|
      $controller.update('line', state.line_id, {complements: complements})
    end
  end

  def create_menu item
    $controller.insert('line', {table: params.table, order_id: params.order_id, menu: true, menu_head: true, price: price(item),
                                item: item, display: display(item), status: 'draft', timestamp: Time.now}).then do |menu_id|
      $controller.rpc('create_menu', params.table, params.order_id, menu_id, steps(item))
      #steps(item).each_with_index do |step, index|
      #  $controller.insert('line', {table: params.table, order_id: params.order_id, menu: true, menu_id: menu_id,
      #                              step: step, index: index, status: 'draft', timestamp: Time.now})
      #end
      state.menu_id! menu_id
    end
  end

  def focus
    lambda do |line_id, step|
      state.line_id! line_id
      state.step! step
      state.type! 'menu'
    end
  end

  def set_item_menu
    lambda do |item|
      if state.line_id
        $controller.update('line', state.line_id, {item: item, display: display(item), scope: scope(item)})
      else
        create_menu item
      end
    end
  end

  def render
    div do
      a(href: '#'){'Carta'}.on(:click){state.type! 'carta'}
      a(href: '#'){'Menu'}.on(:click){state.type! 'menu'}
      br
      ItemInput(tree_item: 'carta', set_item: set_item, set_complements: set_complements) if state.type == 'carta'
      ItemInput(tree_item: state.step, set_item: set_item_menu, set_complements: set_complements) if state.type == 'menu'
      ListItems(order_id: params.order_id, focus: focus)
    end
  end
end

class ListItems < DisplayList

  param :order_id
  param :focus

  before_mount do
    watch_ 'order', params.order_id, []
  end

  def render
    menu = state.docs.select{|x| x['menu']}
    menu_grouped = menu.group_by{|x| x['menu_id']}
    carta = state.docs.select{|x| x['carta']}
    carta_grouped = carta.group_by{|x| {display: x['display'], complements: x['complements']} }
    div do
      menu_grouped.each_pair do |k, v|
        head = state.docs.select{|x| x['id'] == k}[0]
        MenuInput(head: head, data: v, focus: focus)
      end
      carta_grouped.each_pair do |k, v|
        span{k[:display]}
        span(k[:complements])
        span{v.length.to_s}
        span{'-'}.on(:click) do
          line_id = v[0]['id']
          $controller.delete('line', line_id)
        end
      end
    end
  end

end

class MenuInput

  param :head
  param :data
  param :focus, type: Proc

  def render
    div do
      div{params.head['display']}
      params.data.sort{|a, b| a['index'] <=> b['index']}.each do |line|
        div(class: 'menu-input'){line['display']}.on(:click){params.focus line['id'], line['step']}
        div{line['complements']}
      end
    end
  end
end

class ItemInput < React::Component::Base
  param :tree_item
  param :set_item, type: Proc
  param :set_complements, type: Proc

  before_mount do
    state.complements! []
    state.tree_item! nil
  end

  def set_tree_root
    state.tree_item! nil
  end

  def render
    div do
      tree_item = state.tree_item || params.tree_item
      items(tree_item).each do |item|
        if tree? item
          span{display(item)}.on(:click) do
            state.tree_item! item
          end
        else
          span{display(item)}.on(:click) do
            params.set_item item
            state.complements! complements(item)
          end
        end
      end
      br
      state.complements.each do |complement|
        span{complement}.on(:click){params.set_complements complement}
      end
    end
  end
end

