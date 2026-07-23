function cleanEdgeGarbage(text) {
  return text
    // remove bloco edge_all_open_tabs
    .replace(/# User's Edge[\s\S]*?edge_all_open_tabs[\s\S]*?\]/g, "")
    // remove WebsiteContent tags
    .replace(/<WebsiteContent_[^>]+>[\s\S]*?<\/WebsiteContent_[^>]+>/g, "")
    // remove caracteres invisíveis
    .replace(/[\u0000-\u001F\u007F-\u009F]/g, "")
    // remove BOM
    .replace(/^\uFEFF/, "")
    .trim();
}

module.exports = { cleanEdgeGarbage };

