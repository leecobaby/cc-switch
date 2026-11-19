//! 仅供本地截图用（不进 PR）：把一个真实 Claude 会话按阅读页拿到的形态导出成 JSON。
//! `CHAPTER_DUMP_SOURCE=<jsonl> CHAPTER_DUMP_OUT=<dir> cargo test --lib screenshot_dump -- --ignored`

#[test]
#[ignore]
fn screenshot_dump() {
    let source = std::env::var("CHAPTER_DUMP_SOURCE").expect("CHAPTER_DUMP_SOURCE");
    let out =
        std::path::PathBuf::from(std::env::var("CHAPTER_DUMP_OUT").expect("CHAPTER_DUMP_OUT"));
    std::fs::create_dir_all(&out).unwrap();
    let messages = super::load_messages("claude", &source).unwrap();
    let chapters = super::desktop_chapters::chapters_for_source(std::path::Path::new(&source));
    println!(
        "messages: {}, pinned chapters: {}",
        messages.len(),
        chapters.len()
    );
    std::fs::write(
        out.join("messages.json"),
        serde_json::to_vec(&messages).unwrap(),
    )
    .unwrap();
    std::fs::write(
        out.join("chapters.json"),
        serde_json::to_vec(&chapters).unwrap(),
    )
    .unwrap();
}
