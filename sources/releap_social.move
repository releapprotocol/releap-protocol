module releap_social::releap_social {
    use std::string::{String};
    use std::vector::{Self};

    use sui::table::{Self, Table};
    use sui::object::{Self, UID, ID};

    use sui::tx_context::{Self, TxContext};
    use sui::transfer::{Self};
    use sui::package::{Self};
    use sui::display::{Self, Display};
    use sui::clock::{Clock};

    use releap_social::profile ::{Self, Profile, ProfileOwnerCap};
    use releap_social::post::{Self, Post};

    const ERR_NOT_OWNER: u64 = 100;

    struct Witness has drop {}

    struct RELEAP_SOCIAL has drop {}

    struct AdminCap has key { id: UID }
    struct Index has key {
        id: UID,
        profiles: Table<String, ID>
    }

    struct RecentPosts has key {
        id: UID,
        posts: vector<ID>
    }

    fun init(otw: RELEAP_SOCIAL, ctx: &mut TxContext) {
        let index = Index {
            id: object::new(ctx),
            profiles: table::new<String, ID>(ctx)
        };

        let recent_posts = RecentPosts {
            id: object::new(ctx),
            posts: vector::empty()
        };

        transfer::share_object(index);
        transfer::share_object(recent_posts);

        transfer::transfer(AdminCap { id: object::new(ctx) }, tx_context::sender(ctx));
        let publisher = package::claim(otw, ctx);

        let (keys, values) = profile::create_display();
        let profile_display = display::new_with_fields<Profile>(
            &publisher, keys, values, ctx
        );

        let (keys, values) = post::create_display();
        let post_display = display::new_with_fields<Profile>(
            &publisher, keys, values, ctx
        );

        display::update_version(&mut profile_display);
        display::update_version(&mut post_display);

        transfer::public_transfer(publisher, tx_context::sender(ctx));
        transfer::public_transfer(profile_display, tx_context::sender(ctx));
        transfer::public_transfer(post_display, tx_context::sender(ctx));
    }

    public entry fun new_profile(index: &mut Index, name: String, clock: &Clock, ctx: &mut TxContext) {
        let (parsed_name, profile, profile_owner_cap) = profile::new(name, clock, ctx);

        table::add(&mut index.profiles, parsed_name, object::id(&profile));

        transfer::public_transfer(profile_owner_cap, tx_context::sender(ctx));
        transfer::public_share_object(profile);
    }

    public entry fun follow(following_profile: &mut Profile, profile: &mut Profile, profile_owner_cap: &ProfileOwnerCap, _ctx: &mut TxContext) {
        profile::profile_follow(following_profile, profile, profile_owner_cap);      
    }

    public entry fun unfollow(following_profile: &mut Profile, profile: &mut Profile, profile_owner_cap: &ProfileOwnerCap, _ctx: &mut TxContext) {
        profile::profile_unfollow(following_profile, profile, profile_owner_cap);      
    }

    public entry fun update_profile_description(profile: &mut Profile, profile_owner_cap: &ProfileOwnerCap, description: String, _ctx: &mut TxContext) {
        profile::update_profile_description(profile, profile_owner_cap, description, _ctx);
    }

    public entry fun update_profile_image(profile: &mut Profile, profile_owner_cap: &ProfileOwnerCap, image_url: String, _ctx: &mut TxContext) {
        profile::update_profile_image(profile, profile_owner_cap, image_url, _ctx);
    }

    public entry fun update_profile_cover_image(profile: &mut Profile, profile_owner_cap: &ProfileOwnerCap, cover_url: String, _ctx: &mut TxContext) {
        profile::update_cover_image(profile, profile_owner_cap, cover_url, _ctx);
    }

    public entry fun create_post(profile: &mut Profile, profile_owner_cap: &ProfileOwnerCap, recent_posts: &mut RecentPosts, title: String, content: String, clock: &Clock, ctx: &mut TxContext) {
        let post_id = profile::create_post(profile, profile_owner_cap, title, content, clock, ctx);
        update_recent_post(recent_posts, post_id);
    }

    public entry fun create_comment(post: &mut Post, author_profile: &Profile, author_profile_owner_cap: &ProfileOwnerCap, content: String, clock: &Clock, ctx: &mut TxContext) {
        profile::create_comment(post, author_profile, author_profile_owner_cap, content, clock, ctx);
    }

    public entry fun like_post(post: &mut Post, profile: &Profile, profile_owner_cap: &ProfileOwnerCap, ctx: &mut TxContext) {
        profile::like_post(post, profile, profile_owner_cap, ctx);
    }

    public entry fun unlike_post(post: &mut Post, profile: &Profile, profile_owner_cap: &ProfileOwnerCap, ctx: &mut TxContext) {
        profile::unlike_post(post, profile, profile_owner_cap, ctx);
    }

    // Display
    public entry fun admin_add_profile_display(_admin_cap: &AdminCap, display: &mut Display<Profile>, keys: vector<String>, values: vector<String>, _ctx: &mut TxContext) {
        display::add_multiple(display, keys, values);
        display::update_version(display);
    }

    public entry fun admin_remove_profile_display(_admin_cap: &AdminCap, display: &mut Display<Profile>, key: String, _ctx: &mut TxContext) {
        display::remove(display, key);
        display::update_version(display);
    }

    public entry fun admin_add_post_display(_admin_cap: &AdminCap, display: &mut Display<Post>, keys: vector<String>, values: vector<String>, _ctx: &mut TxContext) {
        display::add_multiple(display, keys, values);
        display::update_version(display);
    }

    public entry fun admin_remove_post_display(_admin_cap: &AdminCap, display: &mut Display<Post>, key: String, _ctx: &mut TxContext) {
        display::remove(display, key);
        display::update_version(display);
    }

    fun update_recent_post(recent_posts: &mut RecentPosts, new_post_id: ID) {
        vector::push_back<ID>(&mut recent_posts.posts, new_post_id);
        if (vector::length<ID>(&recent_posts.posts) > 30) {
            // This is O(n) operation
            vector::remove<ID>(&mut recent_posts.posts, 0);
        }
    }

    // getter
    public fun get_recent_post_ids(recent_posts: &RecentPosts): &vector<ID> {
        &recent_posts.posts
    }

    #[test_only]
    public fun test_init(ctx: &mut TxContext) {
        init(RELEAP_SOCIAL{}, ctx);
    }

}

#[test_only]
module releap_social::releap_social_test {
    use releap_social::releap_social::{test_init, Index, RecentPosts, new_profile, follow, unfollow, create_post, update_profile_description, like_post, unlike_post, get_recent_post_ids};
    use sui::test_scenario::{Self, ctx};
    use std::string::{Self};
    use std::vector::{Self};
    use std::option::{Self};
    //use std::debug::{Self};

    use sui::clock::{Self};
    use sui::object::{Self, ID};
    use sui::vec_set::{Self, VecSet};

    use releap_social::profile::{Profile, ProfileOwnerCap, get_profile_description, get_profile_followings_list, get_profile_followers_list, get_profile_followers_count, get_profile_followings_count};
    use releap_social::post::{Post, get_post_liked_count, get_post_liked_profile, get_post_title, get_post_content};

    const ADMIN: address = @0x000000;
    const USER_1: address = @0x000001;
    const USER_2: address = @0x000002;
    const USER_3: address = @0x000003;

    #[test]
    public fun test_create_post() {
        let scenario_val = test_scenario::begin(ADMIN);
        let scenario = &mut scenario_val;
        let clock = clock::create_for_testing(ctx(scenario));

        test_init(ctx(scenario));
        test_scenario::next_tx(scenario, USER_1);

        let social_index = test_scenario::take_shared<Index>(scenario);
        let recent_posts = test_scenario::take_shared<RecentPosts>(scenario);

        new_profile(&mut social_index, string::utf8(b"user 1 name"), &clock, ctx(scenario));
        test_scenario::next_tx(scenario, USER_1);
        let user_1_profile: Profile = test_scenario::take_shared<Profile>(scenario);
        let user_1_owner_cap: ProfileOwnerCap = test_scenario::take_from_address<ProfileOwnerCap>(scenario, USER_1);

        create_post(&mut user_1_profile, &user_1_owner_cap, &mut recent_posts, string::utf8(b"post title"), string::utf8(b"post content"), &clock, ctx(scenario));
        test_scenario::next_tx(scenario, USER_1);
        let post: Post = test_scenario::take_shared<Post>(scenario);
        assert!(get_post_title(&post) == option::some(string::utf8(b"post title")), 1000);
        assert!(get_post_content(&post) == string::utf8(b"post content"), 1000);

        assert!(vector::contains(get_recent_post_ids(&recent_posts), &object::id(&post)), 1000);

        test_scenario::return_shared(social_index);
        test_scenario::return_shared(recent_posts);
        clock::destroy_for_testing(clock);
        test_scenario::return_shared(post);
        test_scenario::return_shared(user_1_profile);
        test_scenario::return_to_address(USER_1, user_1_owner_cap);
        test_scenario::end(scenario_val);
    }

    #[test]
    #[expected_failure]
    public fun test_create_post_with_incorrect_cap() {
        let scenario_val = test_scenario::begin(ADMIN);
        let scenario = &mut scenario_val;
        let clock = clock::create_for_testing(ctx(scenario));

        test_init(ctx(scenario));
        test_scenario::next_tx(scenario, USER_1);

        let social_index = test_scenario::take_shared<Index>(scenario);
        let recent_posts = test_scenario::take_shared<RecentPosts>(scenario);

        new_profile(&mut social_index, string::utf8(b"user 1 name"), &clock, ctx(scenario));
        test_scenario::next_tx(scenario, USER_2);
        let user_1_profile: Profile = test_scenario::take_shared<Profile>(scenario);
        let user_1_owner_cap: ProfileOwnerCap = test_scenario::take_from_address<ProfileOwnerCap>(scenario, USER_1);

        new_profile(&mut social_index, string::utf8(b"user 2 name"), &clock, ctx(scenario));
        test_scenario::next_tx(scenario, USER_1);
        let user_2_profile: Profile = test_scenario::take_shared<Profile>(scenario);
        let user_2_owner_cap: ProfileOwnerCap = test_scenario::take_from_address<ProfileOwnerCap>(scenario, USER_2);

        create_post(&mut user_1_profile, &user_2_owner_cap, &mut recent_posts, string::utf8(b"post title"), string::utf8(b"post content"), &clock, ctx(scenario));

        test_scenario::return_shared(social_index);
        test_scenario::return_shared(recent_posts);
        clock::destroy_for_testing(clock);
        test_scenario::return_shared(user_1_profile);
        test_scenario::return_shared(user_2_profile);
        test_scenario::return_to_address(USER_1, user_1_owner_cap);
        test_scenario::return_to_address(USER_2, user_2_owner_cap);
        test_scenario::end(scenario_val);
    }

    #[test]
    public fun test_profile_following() {
        let scenario_val = test_scenario::begin(ADMIN);
        let scenario = &mut scenario_val;
        let clock = clock::create_for_testing(ctx(scenario));

        test_init(ctx(scenario));
        test_scenario::next_tx(scenario, USER_1);

        let social_index = test_scenario::take_shared<Index>(scenario);
        let recent_posts = test_scenario::take_shared<RecentPosts>(scenario);

        new_profile(&mut social_index, string::utf8(b"user 1 name"), &clock, ctx(scenario));
        test_scenario::next_tx(scenario, USER_2);
        let user_1_profile: Profile = test_scenario::take_shared<Profile>(scenario);

        new_profile(&mut social_index, string::utf8(b"user 2 name"), &clock, ctx(scenario));
        test_scenario::next_tx(scenario, USER_2);
        let user_2_profile = test_scenario::take_shared<Profile>(scenario);
        let user_2_owner_cap = test_scenario::take_from_sender<ProfileOwnerCap>(scenario);

        follow(&mut user_1_profile, &mut user_2_profile, &user_2_owner_cap, ctx(scenario));
        test_scenario::next_tx(scenario, USER_2);
        let followers_list: &VecSet<ID> = get_profile_followers_list(&user_1_profile);
        let followings_list: &VecSet<ID> = get_profile_followings_list(&user_2_profile);

        assert!(vec_set::contains(followers_list, &object::id(&user_2_profile)), 1000);
        assert!(vec_set::contains(followings_list, &object::id(&user_1_profile)), 1000);
        assert!(vec_set::size(followers_list) == 1, 1000);
        assert!(vec_set::size(followings_list) == 1, 1000);

        assert!(get_profile_followers_count(&user_1_profile) == 1, 1000);
        assert!(get_profile_followings_count(&user_2_profile) == 1, 1000);
        
        unfollow(&mut user_1_profile, &mut user_2_profile, &user_2_owner_cap, ctx(scenario));
        test_scenario::next_tx(scenario, USER_2);

        assert!(get_profile_followers_count(&user_1_profile) == 0, 1000);
        assert!(get_profile_followings_count(&user_2_profile) == 0, 1000);
        
        test_scenario::return_shared(social_index);
        test_scenario::return_shared(recent_posts);
        clock::destroy_for_testing(clock);
        test_scenario::return_shared(user_1_profile);
        test_scenario::return_shared(user_2_profile);
        test_scenario::return_to_address(USER_2, user_2_owner_cap);
        test_scenario::end(scenario_val);
    }

    #[test]
    #[expected_failure]
    public fun test_duplicated_profile_name() {
        let scenario_val = test_scenario::begin(ADMIN);
        let scenario = &mut scenario_val;
        let clock = clock::create_for_testing(ctx(scenario));

        test_init(ctx(scenario));
        test_scenario::next_tx(scenario, USER_1);

        let social_index = test_scenario::take_shared<Index>(scenario);
        let recent_posts = test_scenario::take_shared<RecentPosts>(scenario);

        new_profile(&mut social_index, string::utf8(b"profile_1"), &clock, ctx(scenario));
        test_scenario::next_tx(scenario, USER_2);
        let user_1_profile: Profile = test_scenario::take_shared<Profile>(scenario);

        new_profile(&mut social_index, string::utf8(b"Profile_1"), &clock, ctx(scenario));
        test_scenario::next_tx(scenario, USER_2);
        let user_2_profile = test_scenario::take_shared<Profile>(scenario);

        test_scenario::return_shared(social_index);
        test_scenario::return_shared(recent_posts);
        clock::destroy_for_testing(clock);
        test_scenario::return_shared(user_1_profile);
        test_scenario::return_shared(user_2_profile);
        test_scenario::end(scenario_val);
    }

    #[test]
    public fun test_like_post() {
        let scenario_val = test_scenario::begin(ADMIN);
        let scenario = &mut scenario_val;
        let clock = clock::create_for_testing(ctx(scenario));

        test_init(ctx(scenario));
        test_scenario::next_tx(scenario, USER_1);

        let social_index = test_scenario::take_shared<Index>(scenario);
        let recent_posts = test_scenario::take_shared<RecentPosts>(scenario);

        new_profile(&mut social_index, string::utf8(b"User 1"), &clock, ctx(scenario));
        test_scenario::next_tx(scenario, USER_2);
        let user_1_profile = test_scenario::take_shared<Profile>(scenario);
        let user_1_owner_cap = test_scenario::take_from_address<ProfileOwnerCap>(scenario, USER_1);

        new_profile(&mut social_index, string::utf8(b"User 2"), &clock, ctx(scenario));
        test_scenario::next_tx(scenario, USER_1);
        let user_2_profile = test_scenario::take_shared<Profile>(scenario);
        let user_2_owner_cap = test_scenario::take_from_address<ProfileOwnerCap>(scenario, USER_2);

        create_post(&mut user_1_profile, &user_1_owner_cap, &mut recent_posts, string::utf8(b"Post title"), string::utf8(b"Post content"), &clock, ctx(scenario));
        test_scenario::next_tx(scenario, USER_2);
        let post: Post = test_scenario::take_shared<Post>(scenario);

        like_post(&mut post, &user_2_profile, &user_2_owner_cap, ctx(scenario));
        test_scenario::next_tx(scenario, USER_2);

        assert!(get_post_liked_count(&post) == 1, 1000);
        assert!(vec_set::contains(get_post_liked_profile(&post), &object::id(&user_2_profile)), 1000);

        unlike_post(&mut post, &user_2_profile, &user_2_owner_cap, ctx(scenario));
        assert!(get_post_liked_count(&post) == 0, 1000);
        assert!(!vec_set::contains(get_post_liked_profile(&post), &object::id(&user_2_profile)), 1000);
        
        test_scenario::return_to_address(USER_1, user_1_owner_cap);
        test_scenario::return_to_address(USER_2, user_2_owner_cap);
        test_scenario::return_shared(social_index);
        test_scenario::return_shared(recent_posts);
        clock::destroy_for_testing(clock);
        test_scenario::return_shared(user_1_profile);
        test_scenario::return_shared(user_2_profile);
        test_scenario::return_shared(post);
        test_scenario::end(scenario_val);
    }

    #[test]
    public fun test_update_profile_description() {
        let scenario_val = test_scenario::begin(ADMIN);
        let scenario = &mut scenario_val;
        let clock = clock::create_for_testing(ctx(scenario));

        test_init(ctx(scenario));
        test_scenario::next_tx(scenario, USER_1);

        let social_index = test_scenario::take_shared<Index>(scenario);
        let recent_posts = test_scenario::take_shared<RecentPosts>(scenario);

        new_profile(&mut social_index, string::utf8(b"test_user_1"), &clock, ctx(scenario));
        test_scenario::next_tx(scenario, USER_1);
        let user_1_profile = test_scenario::take_shared<Profile>(scenario);
        let user_1_owner_cap = test_scenario::take_from_address<ProfileOwnerCap>(scenario, USER_1);

        assert!(get_profile_description(&user_1_profile) == string::utf8(b""), 1000);
        update_profile_description(&mut user_1_profile, &user_1_owner_cap, string::utf8(b"my description"), ctx(scenario));
        assert!(get_profile_description(&user_1_profile) == string::utf8(b"my description"), 1000);

        test_scenario::return_shared(social_index);
        test_scenario::return_shared(recent_posts);
        test_scenario::return_shared(user_1_profile);
        test_scenario::return_to_address(USER_1, user_1_owner_cap);
        clock::destroy_for_testing(clock);
        test_scenario::end(scenario_val);
    }

    #[test]
    #[expected_failure]
    public fun test_update_profile_description_by_incorrect_cap() {
        let scenario_val = test_scenario::begin(ADMIN);
        let scenario = &mut scenario_val;
        let clock = clock::create_for_testing(ctx(scenario));

        test_init(ctx(scenario));
        test_scenario::next_tx(scenario, USER_1);

        let social_index = test_scenario::take_shared<Index>(scenario);
        let recent_posts = test_scenario::take_shared<RecentPosts>(scenario);

        new_profile(&mut social_index, string::utf8(b"test_user_1"), &clock, ctx(scenario));
        test_scenario::next_tx(scenario, USER_2);
        let user_1_profile = test_scenario::take_shared<Profile>(scenario);
        let user_1_owner_cap = test_scenario::take_from_address<ProfileOwnerCap>(scenario, USER_1);

        new_profile(&mut social_index, string::utf8(b"User 2"), &clock, ctx(scenario));
        test_scenario::next_tx(scenario, USER_1);
        let user_2_profile = test_scenario::take_shared<Profile>(scenario);
        let user_2_owner_cap = test_scenario::take_from_address<ProfileOwnerCap>(scenario, USER_2);

        update_profile_description(&mut user_1_profile, &user_2_owner_cap, string::utf8(b"my description"), ctx(scenario));

        test_scenario::return_shared(social_index);
        test_scenario::return_shared(recent_posts);
        test_scenario::return_shared(user_1_profile);
        test_scenario::return_shared(user_2_profile);
        test_scenario::return_to_address(USER_1, user_1_owner_cap);
        test_scenario::return_to_address(USER_2, user_2_owner_cap);
        clock::destroy_for_testing(clock);
        test_scenario::end(scenario_val);
    }

    #[test]
    #[expected_failure]
    public fun test_create_post_by_incorrect_cap() {
        let scenario_val = test_scenario::begin(ADMIN);
        let scenario = &mut scenario_val;
        let clock = clock::create_for_testing(ctx(scenario));

        test_init(ctx(scenario));
        test_scenario::next_tx(scenario, USER_1);

        let social_index = test_scenario::take_shared<Index>(scenario);
        let recent_posts = test_scenario::take_shared<RecentPosts>(scenario);

        new_profile(&mut social_index, string::utf8(b"test_user_1"), &clock, ctx(scenario));
        test_scenario::next_tx(scenario, USER_2);
        let user_1_profile = test_scenario::take_shared<Profile>(scenario);
        let user_1_owner_cap = test_scenario::take_from_address<ProfileOwnerCap>(scenario, USER_1);

        new_profile(&mut social_index, string::utf8(b"User 2"), &clock, ctx(scenario));
        test_scenario::next_tx(scenario, USER_1);
        let user_2_profile = test_scenario::take_shared<Profile>(scenario);
        let user_2_owner_cap = test_scenario::take_from_address<ProfileOwnerCap>(scenario, USER_2);

        create_post(&mut user_1_profile, &user_2_owner_cap, &mut recent_posts, string::utf8(b"post title"), string::utf8(b"post content"), &clock, ctx(scenario));

        test_scenario::return_shared(social_index);
        test_scenario::return_shared(recent_posts);
        test_scenario::return_shared(user_1_profile);
        test_scenario::return_shared(user_2_profile);
        test_scenario::return_to_address(USER_1, user_1_owner_cap);
        test_scenario::return_to_address(USER_2, user_2_owner_cap);
        clock::destroy_for_testing(clock);
        test_scenario::end(scenario_val);
    }
}


