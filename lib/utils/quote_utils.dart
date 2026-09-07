import 'dart:math';

/// 名言条目
class QuoteItem {
  const QuoteItem(this.text, this.source);

  final String text;
  final String source;
}

/// 内置名言库（理财/生活格言，来源标注；现代口号不挂名人名）
class QuoteUtils {
  QuoteUtils._();

  static final Random _random = Random();
  static int _lastIndex = -1;

  static const List<QuoteItem> _quotes = [
    // ---------- 理财记账 ----------
    QuoteItem('积少成多，聚沙成塔。', '民间谚语'),
    QuoteItem('君子爱财，取之有道。', '《增广贤文》'),
    QuoteItem('由俭入奢易，由奢入俭难。', '司马光《训俭示康》'),
    QuoteItem('省一文是一文。', '英语谚语'),
    QuoteItem('量入为出，细水长流。', '理财格言'),
    QuoteItem('钱要花在刀刃上。', '民间谚语'),
    QuoteItem('节俭本身就是一个大财源。', '西塞罗'),
    QuoteItem('富不过三代，俭可传家。', '民间谚语'),
    QuoteItem('开源节流，双管齐下。', '理财格言'),
    QuoteItem('记账是理财的第一步。', '本应用寄语'),
    QuoteItem('理性消费，快乐生活。', '本应用寄语'),
    QuoteItem('收支有数，心里有底。', '本应用寄语'),
    QuoteItem('你不理财，财不理你。', '现代理财格言'),
    QuoteItem('钱不是万能，但没钱寸步难行。', '民间俗语'),
    QuoteItem('会赚不如会省，会省不如会理。', '理财谚语'),
    QuoteItem('今日省一文，他日成一贯。', '民间谚语'),
    QuoteItem('买东西前先问自己：是想要，还是需要？', '消费格言'),
    QuoteItem('冲动是魔鬼，消费需冷静。', '消费格言'),
    QuoteItem('财富是省出来的，更是理出来的。', '理财格言'),
    QuoteItem('把钱花在提升自己上，是最划算的投资。', '理财格言'),
    // ---------- 古人智慧 ----------
    QuoteItem('一粥一饭，当思来处不易；半丝半缕，恒念物力维艰。', '《朱子家训》'),
    QuoteItem('日计不足，岁计有余。', '古语'),
    QuoteItem('凡事预则立，不预则废。', '《礼记·中庸》'),
    QuoteItem('欲速则不达，见小利则大事不成。', '《论语》'),
    QuoteItem('知足者富。', '《道德经》'),
    QuoteItem('天下难事，必作于易；天下大事，必作于细。', '《道德经》'),
    QuoteItem('不积跬步，无以至千里。', '《荀子》'),
    QuoteItem('仓廪实而知礼节。', '《管子》'),
    QuoteItem('未雨绸缪，有备无患。', '《诗经》'),
    QuoteItem('居安思危，思则有备，有备无患。', '《左传》'),
    QuoteItem('博观而约取，厚积而薄发。', '苏轼'),
    QuoteItem('千里之行，始于足下。', '《道德经》'),
    QuoteItem('合抱之木，生于毫末；九层之台，起于累土。', '《道德经》'),
    QuoteItem('志不强者智不达，言不信者行不果。', '《墨子》'),
    QuoteItem('岁寒，然后知松柏之后凋也。', '《论语》'),
    QuoteItem('工欲善其事，必先利其器。', '《论语》'),
    QuoteItem('知之者不如好之者，好之者不如乐之者。', '《论语》'),
    QuoteItem('学而不思则罔，思而不学则殆。', '《论语》'),
    QuoteItem('三人行，必有我师焉。', '《论语》'),
    QuoteItem('故不积跬步，无以至千里；不积小流，无以成江海。', '《荀子》'),
    QuoteItem('善始者实繁，克终者盖寡。', '《谏太宗十思疏》'),
    QuoteItem('绳锯木断，水滴石穿。', '罗大经《鹤林玉露》'),
    QuoteItem('纸上得来终觉浅，绝知此事要躬行。', '陆游'),
    QuoteItem('山重水复疑无路，柳暗花明又一村。', '陆游'),
    QuoteItem('长风破浪会有时，直挂云帆济沧海。', '李白'),
    QuoteItem('天生我材必有用，千金散尽还复来。', '李白'),
    QuoteItem('人生自古谁无死，留取丹心照汗青。', '文天祥'),
    QuoteItem('先天下之忧而忧，后天下之乐而乐。', '范仲淹'),
    QuoteItem('千磨万击还坚劲，任尔东西南北风。', '郑板桥'),
    QuoteItem('宝剑锋从磨砺出，梅花香自苦寒来。', '《警世贤文》'),
    QuoteItem('路漫漫其修远兮，吾将上下而求索。', '屈原'),
    QuoteItem('天行健，君子以自强不息。', '《周易》'),
    QuoteItem('地势坤，君子以厚德载物。', '《周易》'),
    QuoteItem('静以修身，俭以养德。', '诸葛亮《诫子书》'),
    QuoteItem('非淡泊无以明志，非宁静无以致远。', '诸葛亮《诫子书》'),
    QuoteItem('业精于勤，荒于嬉；行成于思，毁于随。', '韩愈'),
    QuoteItem('书山有路勤为径，学海无涯苦作舟。', '韩愈'),
    QuoteItem('问渠那得清如许？为有源头活水来。', '朱熹'),
    QuoteItem('会当凌绝顶，一览众山小。', '杜甫'),
    QuoteItem('海内存知己，天涯若比邻。', '王勃'),
    QuoteItem('少壮不努力，老大徒伤悲。', '《长歌行》'),
    QuoteItem('明日复明日，明日何其多。', '钱福《明日歌》'),
    QuoteItem('一寸光阴一寸金，寸金难买寸光阴。', '《增广贤文》'),
    QuoteItem('吃得苦中苦，方为人上人。', '民间谚语'),
    QuoteItem('世上无难事，只怕有心人。', '民间谚语'),
    QuoteItem('有志者，事竟成。', '《后汉书》'),
    QuoteItem('锲而不舍，金石可镂。', '《荀子》'),
    QuoteItem('失败是成功之母。', '西方谚语'),
    QuoteItem('行动胜于空谈。', '西方谚语'),
    QuoteItem('时间是金钱。', '本杰明·富兰克林'),
    QuoteItem('早睡早起使人健康、富有、聪明。', '本杰明·富兰克林'),
    QuoteItem('机会总是留给有准备的人。', '现代格言'),
    QuoteItem('细节决定成败。', '现代格言'),
    QuoteItem('态度决定高度。', '现代格言'),
    QuoteItem('坚持就是胜利。', '现代格言'),
    QuoteItem('自律给我自由。', '现代格言'),
    QuoteItem('健康的身体是最大的财富。', '现代格言'),
    QuoteItem('家是温暖的港湾。', '民间俗语'),
    QuoteItem('身体是革命的本钱。', '民间俗语'),
    QuoteItem('平安是福。', '民间俗语'),
    QuoteItem('知足常乐。', '民间谚语'),
    QuoteItem('笑一笑，十年少。', '民间谚语'),
    QuoteItem('一个今天胜过两个明天。', '西方谚语'),
    QuoteItem('种一棵树最好的时间是十年前，其次是现在。', '非洲谚语'),
  ];

  /// 随机取一条（避免与上一次重复）
  static QuoteItem random() {
    if (_quotes.length == 1) return _quotes.first;
    int idx;
    do {
      idx = _random.nextInt(_quotes.length);
    } while (idx == _lastIndex);
    _lastIndex = idx;
    return _quotes[idx];
  }
}
