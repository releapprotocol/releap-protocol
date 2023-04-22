module releap_social::post {
    use std::string::{Self, String};
    use std::vector::{Self};
    use std::option::{Self, Option};

    use sui::object::{Self, UID, ID};
    use sui::dynamic_field as df;
    use sui::clock::{Self, Clock};

    use sui::vec_set::{Self, VecSet};

    use sui::tx_context::{TxContext};

    use releap_social::error::{not_owner};

    friend releap_social::profile;
   
    struct PostOwnerCap has key, store { id: UID, post: ID }

    struct Post has key, store {
        id: UID,
        title: Option<String>,
        content: String,
        created_at: u64,
        profile: ID,
        parent: Option<ID>,
        comment_count: u64,
        like_count: u64,
        author: ID
    }

    fun comments_key(): String {
        string::utf8(b"comments")
    }
    
    fun liked_set_key(): String {
        string::utf8(b"liked_set")
    }

    public(friend) fun create_post(profile_id: ID, title: String, content: String, clock: &Clock, ctx: &mut TxContext): (Post, PostOwnerCap) {
        let post = Post {
                id: object::new(ctx),
                title: option::some(title),
                content: content,
                profile: profile_id,
                parent: option::none(),
                created_at: clock::timestamp_ms(clock),
                author: profile_id,
                comment_count: 0,
                like_count: 0
        };

        let post_owner_cap = PostOwnerCap {
            id: object::new(ctx),
            post: object::id(&post)
        };

        // init empty comment list
        df::add(&mut post.id, comments_key(), vector::empty<ID>());
        df::add(&mut post.id, liked_set_key(), vec_set::empty<ID>());
        (post, post_owner_cap)
    }

    public(friend) fun create_comment(post: &mut Post, author_profile_id: ID, content: String, clock: &Clock, ctx: &mut TxContext): (Post, PostOwnerCap) {
        let comment = Post {
                id: object::new(ctx),
                title: option::none(),
                content: content,
                profile: post.profile,
                parent: option::some(object::id(post)),
                created_at: clock::timestamp_ms(clock),
                author: author_profile_id,
                comment_count: 0,
                like_count: 0
        };

        let comment_owner_cap = PostOwnerCap {
            id: object::new(ctx),
            post: object::id(&comment)
        };

        post.comment_count = post.comment_count + 1;
        let comments: &mut vector<ID> = df::borrow_mut(&mut post.id, comments_key());
        vector::push_back(comments, object::id(&comment));

        // init empty comment list
        df::add(&mut comment.id, comments_key(), vector::empty<ID>());
        df::add(&mut comment.id, liked_set_key(), vec_set::empty<ID>());
        (comment, comment_owner_cap)
    }

    public(friend) fun like_post(post: &mut Post, profile_id: ID) {
        let liked: &mut VecSet<ID> = df::borrow_mut(&mut post.id, liked_set_key());
        vec_set::insert(liked, profile_id);
        post.like_count = post.like_count + 1;
    }

    public(friend) fun unlike_post(post: &mut Post, profile_id: ID) {
        let liked: &mut VecSet<ID> = df::borrow_mut(&mut post.id, liked_set_key());
        vec_set::remove(liked, &profile_id);
        post.like_count = post.like_count - 1;
    }

    public fun get_post_title(post: &Post): Option<String> {
        post.title
    }

    public fun get_post_content(post: &Post): String {
        post.content
    }

    public fun get_post_liked_count(post: &Post): u64 {
        post.like_count
    }

    public fun get_post_liked_profile(post: &Post): &VecSet<ID> {
        df::borrow(&post.id, liked_set_key())
    }

    public fun create_display(): (vector<String>, vector<String>) {
        let keys = vector[
            string::utf8(b"title"),
            string::utf8(b"content"),
            string::utf8(b"created_at"),
            string::utf8(b"like_count"),
            string::utf8(b"comments_count"),
        ];

        let values = vector[
            string::utf8(b"{title}"),
            string::utf8(b"{content}"),
            string::utf8(b"{created_at}"),
            string::utf8(b"{like_count}"),
            string::utf8(b"{comment_count}"),
        ];

        (keys, values)
    }

    public fun assert_post_owner(post: &Post, cap: &PostOwnerCap) {
        assert!(object::id(post) == cap.post, not_owner());
    }
}
