include DatesHelper

Given /^I create community "(.+)"$/ do |community|
  Given %{I go to admin_user's control panel}
  click_link('Manage my groups')
  click_link('Create a new community')
  fill_in("Name", :with => community)
  click_button("Create")
end

Given /^I approve community "(.+)"$/ do |community|
   task = CreateCommunity.all.select {|c| c.name == community}.first
   Given %{I go to admin_user's control panel}
   click_link('Process requests')
   choose("decision-finish-#{task.id}")
   click_button('Apply!')
end

Given /^I reject community "(.+)"$/ do |community|
   task = CreateCommunity.all.select {|c| c.name == community}.first
   Given %{I go to admin_user's control panel}
   click_link('Process requests')
   choose("decision-cancel-#{task.id}")
   click_button('Apply!')
end

Then /^I should see "([^\"]*)"'s creation date$/ do |community|
  com = Community.find_by_name community
  text = "Created at: #{show_date(com.created_at)}"
  has_content?(text)
end
