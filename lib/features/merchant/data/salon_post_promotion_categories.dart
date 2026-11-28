/// 作品的推广分类：决定作品第一张图出现在小程序首页「按分类查找」的哪个分类。
///
/// id 是跨端约定，必须与后端 `src/services/promotion-categories.js`、
/// 小程序 `utils/promotionCategories.js` 一致。`care` 在小程序首页显示为「发质改善」。
const salonPostPromotionCategories = <({String id, String label})>[
  (id: 'women-cut', label: '女士精剪'),
  (id: 'men-cut', label: '男士精剪'),
  (id: 'color', label: '染发'),
  (id: 'curly', label: '卷发'),
  (id: 'straight', label: '直发'),
  (id: 'care', label: '护理'),
];

/// 推广分类的名称；旧作品没有分类（空字符串）或分类未知时返回空字符串。
String salonPostPromotionCategoryLabel(Object? id) {
  for (final category in salonPostPromotionCategories) {
    if (category.id == id) return category.label;
  }
  return '';
}
