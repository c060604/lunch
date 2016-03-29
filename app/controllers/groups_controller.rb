class GroupsController < ApplicationController
  protect_from_forgery with: :null_session, 
    if: Proc.new { |c| c.request.format =~ %r{application/json} }
 
  def index
    group_count = params["count"].to_i
    if group_count <= 0
      group_count = 1
    end
    @lunch_groups = group(group_count, except_array=nil, with_avatar=true)
  end

  def form_group
    puts params
    @users = User.all
    render json: @users
  end

  def create
    text = format_command(params[:text])
    if text.start_with? "lunch member -l"
      # 列出所有成员
      r = list_member_command
    elsif text.start_with? "lunch member -a"
      # 增加成员
      r = add_member_command(text)
    elsif text.start_with? "lunch member -d"
      # 删除成员
      r = del_member_command(text)     
    elsif text.start_with? "lunch group"
      # 分组
      r = group_member_command(text) 
    else
      r = {"text" => help_doc}
    end
    render json: r
  end

  private
    def help_doc
      # 帮助文档
      text = <<-EOF
        `lunch help`: 输出帮助列表。
      `lunch member -l`: 列出所有小伙伴。
      `lunch member -a [name,...]`: 增加小伙伴，如`lunch member -a [c060604]`，增加小伙伴c060604。
      `lunch member -d [name,...]`: 删除小伙伴，将小伙伴从分组列表中删除。
      `lunch group n -e [name,...]`: 分组，如`lunch group 3 -e [c060604,c060605]`，除去c060604和c060605两位后将剩下的小伙伴分成3组（c060604和c060605不参与本次分组）。
      EOF
      r = {
        "attachments" => [
          {
            "text" => text,
            "color" => "#F35A00"
          }
        ]
      }
    end

    def list_member_command
      # 命令：列出所有成员
      value = members.join(", ")
      r = {
        "attachments" => [
          {
            "fields" => [
              {
                "title" => "食家列表:",
                "value" => value,
                "short" => true
              }
            ],
            "color" => "#F35A00"
          }
        ]
      }
    end

    def add_member_command (text)
      # 命令：增加成员
      r, m_range = get_member_str(text)
      if r
        add_array = member_array(text[m_range])
        add_member(add_array)
        r = {
          "attachments" => [
            {
              "text" => "增加小伙伴成功。",
              "color" => "#F35A00"
            }
          ]
        }
      else
        r = help_doc
      end
      return r
    end

    def del_member_command (text)
      # 命令：删除成员
      r, m_range = get_member_str(text)
      if r
        del_array = member_array(text[m_range])
        del_member(del_array)
        r = {
          "attachments" => [
            {
              "text" => "删除小伙伴成功。",
              "color" => "#F35A00"
            }
          ]
        }
      else
        r = help_doc
      end
      return r
    end

    def group_member_command (text)
      # 命令：分组
      begin
        group_count = text.split(' ')[2].to_i
        if group_count == 0
          group_count = 1
        end
        except_array = nil
        if text.index('-e')
          r, m_range = get_member_str(text)
          if r
            member_str = text[m_range]
            except_array = member_array(member_str)
          end
        end
        lunch_groups = group(group_count, except_array)

        i = 1
        attachments = []
        for group in lunch_groups
          fields = []
          fields.push({"title" => "食家 #{i} 组", "value" => group.join(", "), "short" => true})
          attachments.push({"fields" => fields, "color" => "#F35A00"})
          i += 1
        end
        r = {"attachments" => attachments}
      rescue
        r = help_doc
      end
      return r
    end

    def members(with_avatar=false)
      # 获取成员
      users = []
      @users = User.all
      if not with_avatar
        for user in @users
          users.push(user.name)
        end
      else
        for user in @users
          users.push({ "name" => user.name, "avatar" => user.avatar })
        end
      end    
      return users
    end

    def add_member (array)
      # 增加成员
      new_array = []
      for item in array
        item = item.strip
        new_array.push({name: item})
      end
      User.create(new_array)
    end

    def del_member (array)
      # 删除成员
      for item in array
        item = item.strip
        @user = User.find_by name: item
        if @user
          @user.destroy
        end
      end
    end

    def group (group_count=1, except_array=nil, with_avatar=false)
      users = members(with_avatar)
      if except_array != nil
        for item in except_array
          users.delete(item)
        end
      end
      if users.length < group_count
        group_count = 1
      end

      users = shuffle(users)
      groups = []
      num = users.length * 1.0 / group_count

      index = 0
      while index < group_count do
        start_index = index * num
        end_index = start_index + num
        groups.push(users[start_index...end_index]) 
        index += 1
      end

      return groups
    end

    def member_array (member_str)
      # 从字符串提取成员列表
      start_index = 0
      end_index = member_str.length
      if member_str[0] == '['
        start_index = 1
      end
      if member_str[-1] == ']'
        end_index = member_str.length - 1
      end
      member_str = member_str[start_index...end_index]
      member_array = member_str.split(',')
    end

    def format_command (text)
      # 格式化命令
      text_array = text.split(' ')
      text = text_array.join(' ')
    end

    def get_member_str (text)
      # 获取成员字符串
      start_index = text.index('[')
      end_index = text.index(']')
      if start_index and end_index
        return true, start_index..end_index
      else
        return false, nil
      end
    end

    def shuffle (array)
      m = array.length
      while m > 0 do
        # 随机选取一个元素
        i = (rand * m).floor
        m -= 1
        # 交换元素
        array[i], array[m] = array[m], array[i]
      end
      return array
    end
end
