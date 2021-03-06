require File.expand_path(File.dirname(__FILE__) + '/../spec_helper')

describe User do

  before(:each) do
    @valid_params = {
      :password   => 'mypass',
      :password_confirmation => 'mypass',
      :email      => 'email@email.com',
      :first_name  => 'Roman',
      :last_name => 'Snitko',
      :birthdate  => '15.10.1985',
      :city       => 'Saint-Petersburg',
      :region     => 'North-West',
      :country    => 'Russia',
      :notes => 'In every turning leaf, there\'s a pattern of an older tree'
    }
    
    @invalid_params = @valid_params
		@user = User.new()

  end

  it "should NOT create user with invalid email" do
    @invalid_params[:email] = 'bademail'
    @user.update_attributes(@invalid_params)
    @user.errors[:email].should be
  end

  it "should NOT create user with invalid date" do
    
    #wrong date format
    @invalid_params[:birthdate] = 'XIV.X.1985'
    @user.update_attributes(@invalid_params)
    @user.errors[:birthdate].should be

    #wrong age
    @invalid_params[:birthdate] = Time.now.years_ago(1).to_date
    @user.update_attributes(@invalid_params)
		@user.errors[:birthdate].should be

  end


	it "should save empty params as nil" do
		@user.update_attributes(:first_name => "", :last_name => "", :email => "")
		@user.first_name.should   be_nil
		@user.last_name.should    be_nil
    @user.email.should        be_nil
	end


  it "should add errors if tags_string is too long" do
    string = ''
    1.upto(2001) {string += 'w'}
    @user.teach_tags_string =  string
    @user.save
    @user.errors.on(:teach_tags_string).should be
  end



  it "should bot allow ,(comma) in city, region or country" do
    @user.update_attributes(:city => 'bad,city', :region => 'bad,region', :country => 'bad,country')
    @user.errors.on(:city).should     be
    @user.errors.on(:region).should   be
    @user.errors.on(:country).should  be
  end

  it "should downcase city, region and country before save" do
    @user.update_attributes(:city => 'Saint-Petersburg', :region => 'North-West', :country => 'Russia')
    
    @user.send(:read_attribute, :city).should have_text('saint-petersburg')
    @user.send(:read_attribute, :region).should have_text('north-west')
    @user.send(:read_attribute, :country).should have_text('russia')

    @user.city.should have_text("Saint-petersburg")
    @user.region.should have_text("North-west")
    @user.country.should have_text("Russia")
  end

end

describe User, "with tags" do
	
	fixtures :learn_taggings, :users, :tags

	before(:each) do
		@user = User.find(1)
	end

	it "should display all learn tags it has" do
		@user.learn_tags.should be_a_kind_of(Array)
		@user.learn_tags.length.should == 3
	end
	
	it "should update tags" do
		User.create(:learn_tags_string => "jepp, yebrillo, popyatchsa")
		Tag.find_by_string('jepp').should_not be_nil
		Tag.find_by_string('yebrillo').should_not be_nil
		Tag.find_by_string('popyatchsa').should_not be_nil
		Tag.find_by_string('fdjgfdsjgffffs').should be_nil
	end

  it "should downcase tags, when before save" do
    @user.update_attributes(:learn_tags_string => 'Jepp2, YeBrIllO2, POPYATCHSA2')
		Tag.find_by_string('jepp2').should_not be_nil
		Tag.find_by_string('yebrillo2').should_not be_nil
		Tag.find_by_string('popyatchsa2').should_not be_nil
  end

  it "should add errors if learn_tags or teach_tags contain more than 100 tags" do
    string = ''
    1.upto(101) {|i| string += "tag#{i}, "}
    @user.teach_tags_string = string
    @user.learn_tags_string = string
    @user.save
    @user.errors.on(:teach_tags_string).should be
    @user.errors.on(:learn_tags_string).should be
  end

  it "should set user to disabled, if no tags specified" do
    @user.update_attributes(:teach_tags_string => '', :learn_tags_string => '')
    @user.status.should have_text('disabled')
  end

  it "should not allow identical tags" do
    @user.update_attributes(:teach_tags_string => 'tag, tag')
    @user.teach_tags.should have(1).tag
  end

end

describe User, "with avatar" do

  before(:all) do
    @valid_picture1   = { :avatar => file_fixture("/spec/fixtures/files/avatar1.jpg", "image/jpg") }
    @valid_picture2   = { :avatar => file_fixture("/spec/fixtures/files/avatar2.jpg", "image/jpg") }
    @valid_picture3   = { :avatar => file_fixture("/spec/fixtures/files/avatar3.png", "image/png") }
    @valid_picture4   = { :avatar => file_fixture("/spec/fixtures/files/avatar4.gif", "image/gif") }
    class User
      attr_reader :avatar_file
    end
  end

  before(:each) do
    @user = User.new(:email => 'email@email.com')
  end

	it "should save the avatar in file system, then replace it on update" do
		@user.update_attributes(@valid_picture1)
		File.exists?("#{AVATARS_PATH}/#{@user.avatar}").should be_true

		previous_avatar_filename = @user.avatar
		@user.update_attribute(:avatar, @valid_picture2[:avatar])
 		@user.avatar.should_not == previous_avatar_filename

    @user2 = User.find(@user.id)
    @user2.avatar.should_not be_nil
	end

  it "should delete the avatar if the token is set" do
    @user.update_attributes(@valid_picture1)

    @user = User.find_by_email('email@email.com')
    avatar = @user.avatar

    @user.update_attributes({:delete_avatar => true})
    @user.avatar.should be_nil
    File.exists?("#{AVATARS_PATH}/#{avatar}").should be_false
  end

  it "should delete the previous avatar when uploading new" do
    @user.update_attributes(@valid_picture1) 
    old_avatar = "#{AVATARS_PATH}/#{@user.avatar}"
    File.exists?(old_avatar).should be_true

    @user.update_attributes(@valid_picture1)
    new_avatar = "#{AVATARS_PATH}/#{@user.avatar}"
    File.exists?(old_avatar).should be_false
    File.exists?(new_avatar).should be_true
  end

  it "should resize and crop to fit 50x50 px" do
    @user.update_attributes(@valid_picture3)
    @user.avatar_file.rows.should     <= 50
    @user.avatar_file.columns.should  <= 50
  end

  it "should add error when email is duplicated" do
    User.create(:email => 'duplicated@email.com')
    user = User.create(:email => 'duplicated@email.com')
    user.errors.on(:email).should_not be_empty
  end

  after(:all) do
    #cleaning up
    Dir.foreach(AVATARS_PATH) do |dir|
      FileUtils.rm_r("#{AVATARS_PATH}/#{dir}") unless dir.include?('.')
    end
  end

end
