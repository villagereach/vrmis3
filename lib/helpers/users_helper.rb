# Methods added to this helper will be available to all templates in the application.
module UsersHelper
  def password_form_column(record, input_name)
    password_field_tag(input_name)
  end

  def password_confirmation_form_column(record, input_name)
    password_field_tag(input_name)
  end
end
