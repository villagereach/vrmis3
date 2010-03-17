module BasicModelSecurity
  def authorized_for_destroy?
    current_user && current_user.can_edit?
  end

  def authorized_for_create?
    current_user && current_user.can_edit?
  end
  
  def authorized_for_update?
    current_user && current_user.can_edit?
  end
  
#  def authorized_for_read?
#    current_user && current_user.can_edit?
#  end
end
