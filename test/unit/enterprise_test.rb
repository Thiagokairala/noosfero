require File.dirname(__FILE__) + '/../test_helper'

class EnterpriseTest < ActiveSupport::TestCase
  fixtures :profiles, :environments, :users

  def setup
    super
    Environment.default.enable('products_for_enterprises')
    @product_category = fast_create(ProductCategory, :name => 'Products')
  end

  def test_identifier_validation
    p = Enterprise.new
    p.valid?
    assert p.errors.invalid?(:identifier)

    p.identifier = 'with space'
    p.valid?
    assert p.errors.invalid?(:identifier)

    p.identifier = 'áéíóú'
    p.valid?
    assert p.errors.invalid?(:identifier)

    p.identifier = 'rightformat2007'
    p.valid?
    assert ! p.errors.invalid?(:identifier)

    p.identifier = 'rightformat'
    p.valid?
    assert ! p.errors.invalid?(:identifier)

    p.identifier = 'right_format'
    p.valid?
    assert ! p.errors.invalid?(:identifier)
  end

  def test_has_domains
    p = Enterprise.new
    assert_kind_of Array, p.domains
  end

  def test_belongs_to_environment_and_has_default
    assert_equal Environment.default, Enterprise.create!(:name => 'my test environment', :identifier => 'mytestenvironment').environment
  end

  def test_cannot_rename
    p1 = profiles(:johndoe)
    assert_raise ArgumentError do
      p1.identifier = 'bli'
    end
  end

  should 'have fans' do
    p = fast_create(Person)
    e = fast_create(Enterprise)

    p.favorite_enterprises << e

    assert_includes Enterprise.find(e.id).fans, p
  end

  should 'remove products when removing enterprise' do
    e = fast_create(Enterprise, :name => "My enterprise", :identifier => 'myenterprise')
    e.products.create!(:name => 'One product', :product_category => @product_category)
    e.products.create!(:name => 'Another product', :product_category => @product_category)

    assert_difference Product, :count, -2 do
      e.destroy
    end
  end

  should 'create a default set of articles' do
    Enterprise.any_instance.expects(:default_set_of_articles).returns([Blog.new(:name => 'Blog')])
    enterprise = Enterprise.create!(:name => 'my test enterprise', :identifier => 'myenterprise')

    assert_kind_of Blog, enterprise.articles.find_by_path('blog')
    assert_kind_of RssFeed, enterprise.articles.find_by_path('blog/feed')
  end

  should 'create default set of blocks' do
    e = Enterprise.create(:name => 'my new community', :identifier => 'mynewcommunity')

    assert !e.boxes[0].blocks.empty?, 'enterprise must have blocks in area 1'
    assert !e.boxes[1].blocks.empty?, 'enterprise must have blocks in area 2'
    assert !e.boxes[2].blocks.empty?, 'enterprise must have blocks in area 3'
  end

  should 'allow to add new members if has no members' do
    enterprise = fast_create(Enterprise)

    person = fast_create(Person)
    enterprise.add_member(person)

    assert person.is_member_of?(enterprise)
  end

  should 'not allow to add new members' do
    enterprise = fast_create(Enterprise)
    member = fast_create(Person)
    enterprise.add_member(member)
    enterprise.reload

    person = fast_create(Person)
    enterprise.add_member(person)

    assert_equal false, person.is_member_of?(enterprise)
  end

  should 'allow to remove members' do
    c = fast_create(Enterprise, :name => 'my other test profile', :identifier => 'myothertestprofile')
    c.expects(:closed?).returns(false)
    p = create_user('myothertestuser').person

    c.add_member(p)
    assert_includes c.members, p
    c.remove_member(p)
    c.reload
    assert_not_includes c.members, p
  end

  should 'have foudation_year' do
    ent = fast_create(Enterprise, :name => 'test enteprise', :identifier => 'test_ent')

    assert_respond_to ent, 'foundation_year'
    assert_respond_to ent, 'foundation_year='
  end

  should 'have cnpj' do
    ent = fast_create(Enterprise)

    assert_respond_to ent, 'cnpj'
    assert_respond_to ent, 'cnpj='
  end

  should 'block' do
    ent = fast_create(Enterprise, :name => 'test enteprise', :identifier => 'test_ent')
    ent.block
    assert Enterprise.find(ent.id).blocked?
  end

  should 'unblock' do
    ent = fast_create(Enterprise, :name => 'test enteprise', :identifier => 'test_ent')
    ent.data[:blocked] = true
    ent.save
    ent.unblock
    assert !Enterprise.find(ent.id).blocked?
  end

  should 'enable and make user admin' do
    ent = fast_create(Enterprise, :name => 'test enteprise', :identifier => 'test_ent', :enabled => false)
    p = create_user('test_user').person

    assert ent.enable(p)
    ent.reload
    assert ent.enabled
    assert_includes ent.members, p
  end

  should 'replace template if environment allows' do
    template = fast_create(Enterprise, :name => 'template enteprise', :identifier => 'template_enterprise', :enabled => false, :is_template => true)
    template.boxes.destroy_all
    template.boxes << Box.new
    template.boxes[0].blocks << Block.new
    template.save!

    e = Environment.default
    e.replace_enterprise_template_when_enable = true
    e.enterprise_template = template
    e.save!

    ent = fast_create(Enterprise, :name => 'test enteprise', :identifier => 'test_ent', :enabled => false)

    p = create_user('test_user').person
    ent.enable(p)
    ent.reload
    assert_equal 1, ent.boxes.size
    assert_equal 1, ent.boxes[0].blocks.size
  end

  should 'not replace template if environment doesnt allow' do
    inactive_template = fast_create(Enterprise, :name => 'inactive enteprise template', :identifier => 'inactive_enterprise_template', :is_template => true)
    inactive_template.boxes.destroy_all
    inactive_template.boxes << Box.new
    inactive_template.save!

    active_template = Enterprise.create!(:name => 'enteprise template', :identifier => 'enterprise_template')
    assert_equal 3, active_template.boxes.size

    e = Environment.default
    e.inactive_enterprise_template = inactive_template
    e.enterprise_template = active_template
    e.save!

    ent = Enterprise.create!(:name => 'test enteprise', :identifier => 'test_ent', :enabled => false)

    p = create_user('test_user').person
    ent.enable(p)
    ent.reload
    assert_equal 1, ent.boxes.size
  end

  should 'create EnterpriseActivation task when creating with enabled = false' do
    EnterpriseActivation.delete_all
    ent = Enterprise.create!(:name => 'test enteprise', :identifier => 'test_ent', :enabled => false)
    assert_equal [ent], EnterpriseActivation.find(:all).map(&:enterprise)
  end

  should 'create EnterpriseActivation with 7-characters codes' do
    EnterpriseActivation.delete_all
    Enterprise.create!(:name => 'test enteprise', :identifier => 'test_ent', :enabled => false)
    assert_equal 7, EnterpriseActivation.find(:first).code.size
  end

  should 'not create activation task when enabled = true' do
    assert_no_difference EnterpriseActivation, :count do
      fast_create(Enterprise, :name => 'test enteprise', :identifier => 'test_ent', :enabled => true)
    end
  end

  should 'be able to enable even if there are mandatory fields blank' do
    # enterprise is created, waiting for being enabled
    environment = fast_create(Environment, :name => 'my test environment')
    enterprise = fast_create(Enterprise, :name => 'test enterprise', :identifier => 'test_ent', :enabled => false, :environment_id => environment.id)

    # administrator decides now that the 'city' field is mandatory
    environment.custom_enterprise_fields = { 'city' => { 'active' => 'true', 'required' => 'true' } }
    environment.save!
    assert_equal ['city'], environment.required_enterprise_fields

    # then we try to enable the enterprise with a required field is blank
    enterprise = Enterprise.find(enterprise.id)
    person = profiles(:ze)
    assert enterprise.enable(person)
  end

  should 'list product categories full name' do
    subcategory = fast_create(ProductCategory, :name => 'Products subcategory', :parent_id => @product_category.id)
    ent = fast_create(Enterprise, :name => 'test ent', :identifier => 'test_ent')
    p = ent.products.create!(:name => 'test prod', :product_category => subcategory)

    assert_equal [p.category_full_name], ent.product_categories
  end

  should 'not create a products block for enterprise if environment do not let' do
    env = Environment.default
    env.disable('products_for_enterprises')
    ent = fast_create(Enterprise, :name => 'test ent', :identifier => 'test_ent')
    assert_not_includes ent.blocks.map(&:class), ProductsBlock
  end

  should 'have a enterprise template' do
    template = fast_create(Enterprise, :is_template => true)
    p = fast_create(Enterprise, :name => 'test_com', :identifier => 'test_com', :template_id => template.id)
    assert_equal template, p.template
  end

  should 'have a default enterprise template' do
    env = Environment.create!(:name => 'test env')
    p = fast_create(Enterprise, :name => 'test_com', :identifier => 'test_com', :environment_id => env.id)
    assert_kind_of Enterprise, p.template
  end

  should 'have inactive_template even when there is a template set' do
    another_template = fast_create(Enterprise, :is_template => true)
    inactive_template = fast_create(Enterprise, :name => 'inactive enteprise template', :identifier => 'inactive_enterprise_template', :is_template => true)

    e = Environment.default
    e.enable('enterprises_are_disabled_when_created')
    e.inactive_enterprise_template = inactive_template
    e.save!

    ent = Enterprise.create!(:name => 'test enteprise', :identifier => 'test_ent', :template => another_template, :environment => e)
    assert_equal inactive_template, ent.template
  end

  should 'contact us enabled by default' do
    e = fast_create(Enterprise, :name => 'test_com', :identifier => 'test_com', :environment_id => Environment.default.id)
    assert e.enable_contact_us
  end

  should 'return active_enterprise_fields' do
    e = Environment.default
    e.expects(:active_enterprise_fields).returns(['contact_phone', 'contact_email']).at_least_once
    ent = Enterprise.new(:environment => e)

    assert_equal e.active_enterprise_fields, ent.active_fields
  end

  should 'return required_enterprise_fields' do
    e = Environment.default
    e.expects(:required_enterprise_fields).returns(['contact_phone', 'contact_email']).at_least_once
    enterprise = Enterprise.new(:environment => e)

    assert_equal e.required_enterprise_fields, enterprise.required_fields
  end

  should 'require fields if enterprise needs' do
    e = Environment.default
    e.expects(:required_enterprise_fields).returns(['contact_phone']).at_least_once
    enterprise = Enterprise.new(:environment => e)
    assert ! enterprise.valid?
    assert enterprise.errors.invalid?(:contact_phone)

    enterprise.contact_phone = '99999'
    enterprise.valid?
    assert ! enterprise.errors.invalid?(:contact_phone)
  end

  should 'enable contact' do
    enterprise = Enterprise.new(:enable_contact_us => false)
    assert !enterprise.enable_contact?
    enterprise.enable_contact_us = true
    assert enterprise.enable_contact?
  end

  should 'save organization_website with http' do
    p = Enterprise.new(:name => 'test_ent', :identifier => 'test_ent')
    p.organization_website = 'website.without.http'
    p.save!
    assert_equal 'http://website.without.http', p.organization_website
  end

  should 'save not add http to empty organization_website' do
    p = Enterprise.new(:name => 'test_ent', :identifier => 'test_ent')
    p.organization_website = ''
    p.save!
    assert_equal '', p.organization_website
  end

  should 'save organization_website as typed if has http' do
    p = Enterprise.new(:name => 'test_ent', :identifier => 'test_ent')
    p.organization_website = 'http://website.with.http'
    p.save
    assert_equal 'http://website.with.http', p.organization_website
  end

  should 'be created disabled if feature enterprises_are_disabled_when_created is enabled' do
    e = Environment.default
    e.enable('enterprises_are_disabled_when_created')
    e.save!

    ent = Enterprise.create!(:name => 'test enteprise', :identifier => 'test_ent')
    assert_equal false, Enterprise['test_ent'].enabled?
  end

  should 'enterprise is validated according to feature enterprises_are_validated_when_created' do
    e = Environment.default

    e.enable('enterprises_are_validated_when_created')
    e.save
    enterprise = Enterprise.create(:name => 'test enteprise', :identifier => 'test_ent1')
    assert enterprise.validated

    e.disable('enterprises_are_validated_when_created')
    e.save
    enterprise = Enterprise.create(:name => 'test enteprise', :identifier => 'test_ent2')
    assert !enterprise.validated
  end

  should 'have inactive_template when creating enterprise and feature is enabled' do
    inactive_template = fast_create(Enterprise, :name => 'inactive enteprise template', :identifier => 'inactive_enterprise_template', :is_template => true)
    inactive_template.boxes.destroy_all
    inactive_template.boxes << Box.new
    inactive_template.save!

    e = Environment.default
    e.enable('enterprises_are_disabled_when_created')
    e.inactive_enterprise_template = inactive_template
    e.save!

    ent = Enterprise.create!(:name => 'test enteprise', :identifier => 'test_ent')
    assert_equal 1, ent.boxes.size
  end

  should 'have active_template when creating enterprise and feature is disabled' do
    inactive_template = fast_create(Enterprise, :name => 'inactive enteprise template', :identifier => 'inactive_enterprise_template', :is_template => true)
    inactive_template.boxes.destroy_all
    inactive_template.boxes << Box.new
    inactive_template.save!

    e = Environment.default
    e.disable('enterprises_are_disabled_when_created')
    e.inactive_enterprise_template = inactive_template
    e.save!

    ent = Enterprise.create!(:name => 'test enteprise', :identifier => 'test_ent')
    assert_equal 3, ent.boxes.size
  end

  should 'collect the highlighted products with image' do
    env = Environment.default
    e1 = fast_create(Enterprise)
    p1 = e1.products.create!(:name => 'test_prod1', :product_category_id => @product_category.id)
    products = []
    3.times {|n|
      products.push(Product.create!(:name => "product #{n}", :profile_id => e1.id,
        :highlighted => true, :product_category_id => @product_category.id,
        :image_builder => { :uploaded_data => fixture_file_upload('/files/rails.png', 'image/png') }
      ))
    }
    Product.create!(:name => "product 4", :profile_id => e1.id, :product_category_id => @product_category.id, :highlighted => true)
    Product.create!(:name => "product 5", :profile_id => e1.id, :product_category_id => @product_category.id, :image_builder => {
      :uploaded_data => fixture_file_upload('/files/rails.png', 'image/png')
    })
    assert_equal products, e1.highlighted_products_with_image
  end

  should 'has many inputs through products' do
    enterprise = fast_create(Enterprise)
    product = fast_create(Product, :profile_id => enterprise.id, :product_category_id => @product_category.id)
    product.inputs << Input.new(:product_category => @product_category)
    product.inputs << Input.new(:product_category => @product_category)

    assert_equal product.inputs, enterprise.inputs
  end

  should "the followed_by? be true only to members" do
    e = fast_create(Enterprise)
    e.stubs(:closed?).returns(false)
    p1 = fast_create(Person)
    p2 = fast_create(Person)
    p3 = fast_create(Person)

    assert !p1.is_member_of?(e)
    e.add_member(p1)
    assert p1.is_member_of?(e)

    assert !p3.is_member_of?(e)
    e.add_member(p3)
    assert p3.is_member_of?(e)

    assert_equal true, e.send(:followed_by?,p1)
    assert_equal true, e.send(:followed_by?,p3)
    assert_equal false, e.send(:followed_by?,p2)
  end

  should 'receive scrap notification' do
    enterprise = fast_create(Enterprise)
    assert_equal false, enterprise.receives_scrap_notification?
  end

  should 'have production cost' do
    e = fast_create(Enterprise)
    assert_respond_to e, :production_costs
  end

  should 'return scraps as activities' do
    person = fast_create(Person)
    enterprise = fast_create(Enterprise)


    activity = ActionTracker::Record.last
    scrap = Scrap.create!(defaults_for_scrap(:sender => person, :receiver => enterprise, :content => 'A scrap'))

    assert_equal [scrap], enterprise.activities.map { |a| a.klass.constantize.find(a.id) }
  end

  should 'return tracked_actions of community as activities' do
    person = fast_create(Person)
    enterprise = fast_create(Enterprise)

    UserStampSweeper.any_instance.expects(:current_user).returns(person).at_least_once
    article = create(TinyMceArticle, :profile => enterprise, :name => 'An article about free software')

    assert_equal [article.activity], enterprise.activities.map { |a| a.klass.constantize.find(a.id) }
  end

  should 'not return tracked_actions of other community as activities' do
    person = fast_create(Person)
    enterprise = fast_create(Enterprise)
    enterprise2 = fast_create(Enterprise)

    UserStampSweeper.any_instance.expects(:current_user).returns(person).at_least_once
    article = create(TinyMceArticle, :profile => enterprise2, :name => 'Another article about free software')

    assert_not_includes enterprise.activities.map { |a| a.klass.constantize.find(a.id) }, article.activity
  end

  should 'provide URL to catalog area' do
    environment = create_environment('mycolivre.net')
    enterprise = build(Enterprise, :identifier => 'testprofile', :environment_id => create_environment('mycolivre.net').id)

    assert_equal({:profile => enterprise.identifier, :controller => 'catalog'}, enterprise.catalog_url)
  end


end
