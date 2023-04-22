module releap_social::profile {
    use std::string::{Self, String};
    use std::ascii::{Self};
    use std::vector::{Self};

    use sui::object::{Self, UID, ID};
    use sui::vec_set::{Self, VecSet};
    use sui::dynamic_field as df;

    use sui::tx_context::{Self, TxContext};
    use sui::transfer::{Self};
    use sui::clock::{Self, Clock};

    use releap_social::post::{Self, Post};
    use releap_social::error::{not_owner, profile_name_too_short, unexpected_char_in_profile_name};

    friend releap_social::releap_social;

    struct Profile has key, store {
        id: UID,
        name: String,
        description: String,
        website: String,
        image_url: String,
        cover_url: String,
        followers_count: u64,
        followings_count: u64,
        created_at: u64
    }

    struct ProfileOwnerCap has key, store { id: UID, profile: ID }


    fun followers_key(): String {
        string::utf8(b"followers")
    }
    fun followings_key(): String {
        string::utf8(b"followings")
    }
    fun posts_key(): String {
        string::utf8(b"posts")
    }

    public fun new(name: String, clock: &Clock, ctx: &mut TxContext): (String, Profile, ProfileOwnerCap) {
        let name_checked = parse_and_verifiy_profile_name(name);
        let profile = Profile {
            name: name_checked,
            description: string::utf8(b""),
            website: string::utf8(b""),
            image_url: string::utf8(b""),
            cover_url: string::utf8(b""),
            id: object::new(ctx),
            followers_count: 0,
            followings_count: 0,
            created_at: clock::timestamp_ms(clock),
        };

        let profile_owner_cap = ProfileOwnerCap {
            id: object::new(ctx),
            profile: object::id(&profile)
        };

        df::add(&mut profile.id, followers_key(), vec_set::empty<ID>());
        df::add(&mut profile.id, followings_key(), vec_set::empty<ID>());
        df::add(&mut profile.id, posts_key(), vector::empty<ID>());

        return (name_checked, profile, profile_owner_cap)
    }

    public fun profile_follow(following_profile: &mut Profile, profile: &mut Profile, profile_owner_cap: &ProfileOwnerCap) {
        assert_profile_owner(profile, profile_owner_cap);

        let followers_list = df::borrow_mut(&mut following_profile.id, followers_key());
        vec_set::insert(followers_list, object::id(profile)); let followings_list = df::borrow_mut(&mut profile.id, followings_key());
        vec_set::insert(followings_list, object::id(following_profile));

        following_profile.followers_count = following_profile.followers_count + 1;
        profile.followings_count = profile.followings_count + 1;
    }

    public fun profile_unfollow(following_profile: &mut Profile, profile: &mut Profile, profile_owner_cap: &ProfileOwnerCap) {
        assert_profile_owner(profile, profile_owner_cap);

        let followers_list = df::borrow_mut(&mut following_profile.id, followers_key());
        vec_set::remove(followers_list, &object::id(profile));

        let followings_list = df::borrow_mut(&mut profile.id, followings_key());
        vec_set::remove(followings_list, &object::id(following_profile));

        following_profile.followers_count = following_profile.followers_count - 1;
        profile.followings_count = profile.followings_count - 1;
    }

    public fun create_post(profile: &mut Profile, profile_owner_cap: &ProfileOwnerCap, title: String, content: String, clock: &Clock, ctx: &mut TxContext): ID {
        assert_profile_owner(profile, profile_owner_cap);

        let (post, post_owner_cap) = post::create_post(object::id(profile), title, content, clock, ctx);

        let posts: &mut vector<ID> = df::borrow_mut(&mut profile.id, posts_key());

        let post_id = object::id(&post);
        vector::push_back(posts, post_id);

        transfer::public_transfer(post_owner_cap, tx_context::sender(ctx));
        transfer::public_share_object(post);

        return post_id
    }

    public fun create_comment(post: &mut Post, profile: &Profile, profile_owner_cap: &ProfileOwnerCap, content: String, clock: &Clock, ctx: &mut TxContext) {
        assert_profile_owner(profile, profile_owner_cap);

        let (post, post_owner_cap) = post::create_comment(post, object::id(profile), content, clock, ctx);

        transfer::public_transfer(post_owner_cap, tx_context::sender(ctx));
        transfer::public_share_object(post);
    }

    public entry fun update_profile_description(profile: &mut Profile, profile_owner_cap: &ProfileOwnerCap, description: String, _ctx: &mut TxContext) {
        assert_profile_owner(profile, profile_owner_cap);
        profile.description = description;
    }

    public entry fun update_profile_image(profile: &mut Profile, profile_owner_cap: &ProfileOwnerCap, image_url: String, _ctx: &mut TxContext) {
        assert_profile_owner(profile, profile_owner_cap);
        profile.image_url = image_url;
    }

    public entry fun update_cover_image(profile: &mut Profile, profile_owner_cap: &ProfileOwnerCap, cover_url: String, _ctx: &mut TxContext) {
        assert_profile_owner(profile, profile_owner_cap);
        profile.cover_url = cover_url;
    }

    public fun assert_profile_owner(profile: &Profile, cap: &ProfileOwnerCap) {
        assert!(object::id(profile) == cap.profile, not_owner());
    }

    public fun assert_profile_id_owner(profile_id: ID, cap: &ProfileOwnerCap) {
        assert!(profile_id == cap.profile, not_owner());
    }

    // getter
    public fun get_profile_followers_list(profile: &Profile): &VecSet<ID> {
        df::borrow(&profile.id, followers_key())
    }

    public fun get_profile_followings_list(profile: &Profile): &VecSet<ID> {
        df::borrow(&profile.id, followings_key())
    }

    public fun get_profile_followers_count(profile: &Profile): u64 {
        profile.followers_count
    }

    public fun get_profile_followings_count(profile: &Profile): u64 {
        profile.followings_count
    }

    public fun get_profile_description(profile: &Profile): String {
        profile.description
    }

    public fun get_post(profile: &Profile): &vector<ID> {
        return df::borrow(&profile.id, posts_key())
    }

    public entry fun like_post(post: &mut Post, profile: &Profile, profile_owner_cap: &ProfileOwnerCap, _ctx: &mut TxContext) {
        assert_profile_owner(profile, profile_owner_cap);
        post::like_post(post, object::id(profile));
    }

    public entry fun unlike_post(post: &mut Post, profile: &Profile, profile_owner_cap: &ProfileOwnerCap, _ctx: &mut TxContext) {
        assert_profile_owner(profile, profile_owner_cap);
        post::unlike_post(post, object::id(profile));
    }

    fun parse_and_verifiy_profile_name(name: String): String {
        let ascii_name = string::to_ascii(name);
        let length = ascii::length(&ascii_name);
        let bytes = &mut ascii::into_bytes(ascii_name);

        assert!(ascii::all_characters_printable(&ascii_name), unexpected_char_in_profile_name());
        assert!(length >= 5, profile_name_too_short());

        let i = 0;
        while(i < length) {
            let ch: &mut u8 = vector::borrow_mut<u8>(bytes, i);

            if (*ch >= 65 && *ch <= 90) {
                // convert to lower case
                *ch = *ch + 32;
            } else {
                let ch = *ch;
                let valid_ascii = ch >= 97 && ch <= 122 // lower case
                    || ch >= 48 && ch <= 57 // number
                    || ch == 32 // space
                    || ch == 45 // dash
                    || ch == 95; // underscore

                assert!(valid_ascii , unexpected_char_in_profile_name());
            };
            i = i + 1;
        };

        let ascii_name = ascii::string(*bytes);
        string::from_ascii(ascii_name)
    }

    public fun create_display(): (vector<String>, vector<String>) {
        let keys = vector[
            string::utf8(b"name"),
            string::utf8(b"image_url"),
            string::utf8(b"description"),
            string::utf8(b"followers_count"),
            string::utf8(b"following_count"),
        ];
        let values = vector[
            string::utf8(b"{name}"),
            string::utf8(b"{image_url}"),
            string::utf8(b"{description}"),
            string::utf8(b"{followers_count}"),
            string::utf8(b"{following_count}"),
        ];

        (keys, values)
    }

    #[test]
    fun test_convert_profile_name_to_lowercase() {
        assert!(parse_and_verifiy_profile_name(string::utf8(b"Test_- abc")) == string::utf8(b"test_- abc"), 1000);
        assert!(parse_and_verifiy_profile_name(string::utf8(b"test_- abc")) == string::utf8(b"test_- abc"), 1000);
    }

    #[test]
    #[expected_failure]
    fun test_short_profile_name() {
        assert!(parse_and_verifiy_profile_name(string::utf8(b"test")) == string::utf8(b"test_abc"), 1000);
    }

    #[test]
    #[expected_failure]
    fun test_invaild_char_1() {
        assert!(parse_and_verifiy_profile_name(string::utf8(b"test##")) == string::utf8(b"test_abc"), 1000);
    }

    #[test]
    #[expected_failure]
    fun test_invaild_char_2() {
        assert!(parse_and_verifiy_profile_name(string::utf8(b"test%%")) == string::utf8(b"test_abc"), 1000);
    }
}
