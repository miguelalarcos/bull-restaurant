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
  $items[item]['complements'] || []
end

def price item
  $items[item]['price']
end

def steps item
  $item[item]['steps']
end

# ###

def set_item order_id
  lambda do |item|
    $controller.insert('line', {order_id: order_id, item: item, price: price(item), display: display(item)})
  end
end

# ###

class MenuTab < React::Component::Base

  param :order_id

  before_mount do
    clear
  end

  def clear
    state.menu_id! nil
    state.line_id! nil
    state.step! nil
  end

  def create_menu item
    $controller.insert('line', {order_id: params.order_id, menu: true, menu_head: true, item: item, display: display(item)}).then do |menu_id|
      #$controller.rpc('create_menu', params.order_id, menu_id, steps(item))
      steps(item).each_with_index do |step, index|
        $controller.insert('line', {order_id: params.order_id, menu: true, menu_id: menu_id, step: step, index: index})
      end
      state.menu_id! menu_id
    end
  end

  def focus
    lambda do |line_id, step|
      state.line_id! line_id
      state.step! step
    end
  end

  def set_item_menu
    lambda do |item|
      $controller.update('line', state.line_id, {item: item, display: display(item)})
    end
  end

  def set_complements
    lambda do |complements|
      $controller.update('line', state.line_id, {complements: complements})
    end
  end

  def ok
    lambda do
      clear
    end
  end

  def cancel
    lambda do
      $controller.rpc('remove_menu', state.menu_id)
      clear
    end
  end

  def render
    div do
      ItemInput(tree_item: 'menus', set_item: lambda{|item| create_menu item}) if !state.step
      ItemInput(tree_item: state.step, set_item: set_item_menu, set_complements: set_complements) if state.step
      MenuInput(menu_id: state.menu_id, focus: focus, ok: ok) if state.menu_id
    end
  end
end

class MenuInput < DisplayList
  param :menu_id
  param :focus, type: Proc
  param :ok, type: Proc
  param :cancel, type: Proc

  before_mount do
    watch_ 'menu', params.menu_id, []
  end

  def render
    div do
      state.docs.select{|x| !x['menu_head']}.sort{|a, b| a['index'] <=> b['index']}.each do |line|
        div{line['display'] || 'click'}.on(:click){params.focus line['id'], line['step']}
        div{line['complements']}
      end
      div{'Ok'}.on(:click){params.ok}
      div{'Cancelar'}.on(:click){params.cancel}
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

