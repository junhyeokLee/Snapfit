import 'dart:convert';
import 'dart:math' as math;

import 'package:crypto/crypto.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:snap_fit/core/templates/authored_collections.dart';
import 'package:snap_fit/core/templates/data_template_engine.dart';
import 'package:snap_fit/core/templates/free_template_material_policy.dart';
import 'package:snap_fit/features/album/data/bundled_creation_templates.dart';
import 'package:snap_fit/features/album/domain/entities/album_creation_template.dart';
import 'package:snap_fit/features/album/domain/entities/layer.dart';
import 'package:snap_fit/features/album/domain/entities/layer_export_mapper.dart';
import 'package:snap_fit/features/point_shop/domain/point_shop_launch_pricing.dart';
import 'package:snap_fit/features/point_shop/domain/point_shop_template_key.dart';

const _record = bool.fromEnvironment('RECORD_FREE_CATALOG_BASELINE');
final _loadedFontFamilies = <String>{};
const _catalogIds = {
  'lightbound': -9301,
  'journey': -9302,
  'small-days': -9303,
  'wind-atlas': -9304,
  'our-prose': -9305,
  'our-vows': -9401,
  'garden-promise': -9402,
  'one-fine-film': -9403,
  'love-letters': -9404,
  'across-the-sea': -9411,
  'city-collector': -9412,
  'slow-paths': -9413,
  'travel-postbox': -9414,
  'seasonal-table': -9421,
  'taste-archive': -9422,
  'better-together': -9423,
  'weekend-temperature': -9424,
  'your-first-year': -9431,
  'little-footsteps': -9432,
  'you-are-spring': -9433,
  'growing-in-color': -9434,
  'first-birthday': -9435,
  'our-family-year': -9441,
  'around-our-table': -9442,
  'our-good-company': -9443,
  'across-generations': -9444,
  'a-picnic-together': -9445,
  'dates-of-us': -9451,
  'scenes-for-two': -9452,
  'seasons-of-love': -9453,
  'still-us': -9454,
  'collected-by-two': -9455,
  'a-day-with-you': -9461,
  'shapes-of-naps': -9462,
  'our-walking-promise': -9463,
  'our-little-companion': -9464,
  'the-kindest-face': -9465,
  'alley-afternoon': -9471,
  'saturday-together': -9472,
  'daily-paw-walk': -9473,
  'our-first-promise': -9474,
  'little-day-discoveries': -9475,
};

// Filled from the pre-change shipping factory after all bundled fonts load.
// Only fixed hashes are retained; no document or artwork snapshots are saved.
const _baseline = <String, dynamic>{
  "portrait": {
    "protected":
        "d7f7ab848e3fb1465745a024b735a3f649076df06c1fda3a3f7afde86bcfe5b5",
    "covers": {
      "lightbound":
          "1ffbee3eaad0b69a648ca504ea0009326c18d417a8755a020add2a85eebb8f5d",
      "journey":
          "06b3eaee6785302943657fff781c119d54189ccf5842ab91eed7e3d13d07d302",
      "small-days":
          "f7b40978d7331b0f925b7de2d431050e78f74aa543679d57e6c0bb9b2d2bf056",
      "our-vows":
          "7d8f3974194e09ec32b4b7c621b297e38cbdb25601584d1bf888571219f469bf",
      "garden-promise":
          "abdc6dd133a8caf3fdb1abd516de574cd4c75483f6654b50313e4aa1ccb60e6a",
      "one-fine-film":
          "69e050d4723fee4391833c7e3012b19ba0ae043fd46b9e520ed2a6542a965808",
      "love-letters":
          "73023e53db5fc1a2fa0908642615547372c5397635c7a61fa714dbbb29171ba6",
      "across-the-sea":
          "e84441f26e734bb9dad4ff46024d493272f37ef8bff99ca5df194a73ebcf27c6",
      "city-collector":
          "92a4f0d77900f39a23343257d3e5ef530350a9b141290aef61689747e737e930",
      "slow-paths":
          "b87489ddbfc78219fca7f514993ee539e510dfd3a81e5c9e20a53e88d11a861d",
      "travel-postbox":
          "60169908a9f3be5c9a08d2af3a4b71b4b849f30795adf907b320d94d67d529cd",
      "seasonal-table":
          "46de2c740dc4322ba724978f2320b6052189981e5ba01a99fef216591e112c38",
      "taste-archive":
          "aaff18d2b2f6ee1003f6a5c3527310c15e1e527872a7bbdb8f61e9b83cae5038",
      "better-together":
          "43233da63733818f1565ec64f3c9ab8b16a8063a4cd9ad83ad00a47cddcb403a",
      "weekend-temperature":
          "3f0d18e1a2771721ab10d7737a59628198981083c9e0f8e966d43f58c42e8370",
      "your-first-year":
          "88bdc50390f297e1c840fb1316d22fdebfcde3c237698c3e28010d97132e43e8",
      "little-footsteps":
          "9f47a414e5253b84eee52e5705eb5b3740ce0430ae552f567e5b2a2bf1956486",
      "you-are-spring":
          "db41373dddb34eb58f2ac35fb53fd8002833b794054ae88f00b241e4db24e9cc",
      "growing-in-color":
          "b2b25311b21dea7915d993eacfd376e6f83073fe9f652deab1df9064a73f0b77",
      "first-birthday":
          "e83442acd8109b32e6caed268d4c347cfcbc9d141d6c13220176102f9a8309f7",
      "our-family-year":
          "c0cfe337733a45e042202741c439221af73213405c75a18710ffe96467be30ec",
      "around-our-table":
          "8b292f6652bf2335680ee0410d2cce17e1b9148695b72875057d9bd308b620c6",
      "our-good-company":
          "36b9ca6550fd562107aec59ca4622eecdc2ed1d03e1b153f5a88d7ef7bef60dc",
      "across-generations":
          "001bfe39816c9914eb7321f922d3c11434727fa9ddbcf251d7c3cc565f6b5794",
      "a-picnic-together":
          "33bedd7ba0959ee8f59d4a17dbc59372687d9d7a25ac37cad90453438faa8da3",
      "dates-of-us":
          "049e85af090e84fa38b8308aa12308881902e2b562da4f918bdb4fecc0d9065c",
      "scenes-for-two":
          "d58436b465c049c6bc43496fadecf7ae1d6a40a85f907b8b4b326130fb79faa9",
      "seasons-of-love":
          "c3486299671da5a66ffc6a52996550943893a17ea8b51009c8ce5aa0de8ebf93",
      "still-us":
          "1d32c80ab5095a75bfc8201263c88c86cd3e7c1799ccc48cfc158598019b72b7",
      "collected-by-two":
          "e5cd505a7985c7d2ffb71dbf92ee6e3bc39178be61327b643cf73fe6920a36ff",
      "a-day-with-you":
          "fd95fcbb21a8e70ad02482e43e5a22ab570bb105f0e189b575ea3813032729b1",
      "shapes-of-naps":
          "6243fe07ec8037da80bce3239ed5f0fc003e26d9a6b20bfa6aed5278604745f6",
      "our-walking-promise":
          "cddd2e98e7a631f7a1e21a9b84f919d21f178ffa065675cbcce091e8b8d8069e",
      "our-little-companion":
          "abbc7f508a6a5610ec1b63252489a3d2b915779990c61707cac052362d5bd922",
      "the-kindest-face":
          "1bfb80b1ad83a198e9aa1c9d69dee9511d3219254725493a64cdd4664a65db48",
      "wind-atlas":
          "7aa2fbaebb19788a69417a25782a73c69ce38bc16f4bf327501d338918ccb521",
      "our-prose":
          "1e8867b85ee4f01c6f84efd67e740e34029acc31c52029e65a2bdc880f6b5522",
      "alley-afternoon":
          "e747945b995c11485b2f82ddf1ed44a1bad110b8a089f68ef8647266ab42f17e",
      "saturday-together":
          "ea90ac314b2f1262bad8a45793eca56d3766ed779ae95145ec039a7da875ab77",
      "daily-paw-walk":
          "ed3cacbacad2153678a8b6c94110ae16eb858d5f6060ba222d7c8c5c46c6c3f9",
      "our-first-promise":
          "6fa404b0d5ccd2a54e0ee00d68b9a0e96a245cc08eee6bfd9fc9ddd8c90e1e03",
      "little-day-discoveries":
          "1ab83f7c28164d0db3ce91ff3e2825153911888694b8b0148a951a1e2cc62a1e",
    },
  },
  "square": {
    "protected":
        "2bb6ce536e2bb413e639b2fd8c95d7744c2fbb7284a7ced613d07877116402ee",
    "covers": {
      "lightbound":
          "bf001cfb7078650a8c7f38826cab50b4e0d0695ed2426d194b2f79a4879cffc3",
      "journey":
          "2e437e4d9408538ba2df3761ceed25795533940297dfd041eae34ade676a2551",
      "small-days":
          "8a764a4407703e4484d0dedfbfca82831a1a20ec9e281afe4a8df5a4db0ee9af",
      "our-vows":
          "f8a84e00e4e6716fdaf8929fcbc0f9c36b7d2f6140ddbf4a01bf5f631d8699e8",
      "garden-promise":
          "4ba6b370d83a85f2246f9ec1762d6e4c840862dd1b881d3bd29e9d8b63039e01",
      "one-fine-film":
          "21edc8862117d83cb22ba2547e95b24711643bd381e5d62e70150426f0c5f496",
      "love-letters":
          "a74bb037edf4586020880d10e951fe307a1e0b9d88ccbcc907a1c168c97dbda9",
      "across-the-sea":
          "99d9881e0a1dda8ad2190b18a420ac074d0a14c67e7ef11e2cac880c3872104c",
      "city-collector":
          "2815c7d6a1f5853a6afc7f887ae3011780ae0c9f4a2fac2150049eec0b6d35dc",
      "slow-paths":
          "d693da95460caf148ee4db0515343cc87124ce920d1cbb87205960d585e5551b",
      "travel-postbox":
          "39edd1643544b4c1773839726fc46f07a991fb2dd20ac012bc6c46fa3b9d05f5",
      "seasonal-table":
          "d00e802e0f1a7a62a2e95d8f936e0f8087792d04cf1accb1fa6c1f2e368639c2",
      "taste-archive":
          "dd257c48898949731f140786660f03aabe97fc21637cacd537241aa420dee0cf",
      "better-together":
          "446f1fa77a2dc4cd14803bcdde300b3aa64772b1beb979d6e84f9c8be386ce24",
      "weekend-temperature":
          "9e348fef5dfdc50741816fed0fb546da12bb7b220bca5e7555d21b2ef75ead54",
      "your-first-year":
          "96bfe43b4ee3d1efbec6de15006cd7c73c305385c33cb77c66595b0189b287a1",
      "little-footsteps":
          "f111c31d4e5c72644402770e420c2a6a6345f48f978aa48957ffd4439af34b2d",
      "you-are-spring":
          "2988d2fa41bf9d52448032c72453ce96b5906f89fd2f66a52c5e2b49e4dd68ca",
      "growing-in-color":
          "2903a20a3fb87bd5b9a2c391eac1626862f0a6c9cff84de48f53e389c2327949",
      "first-birthday":
          "44ce96a6ddf6097f94906d1102e378c90bef4e140c4c800abd65c2e867b28801",
      "our-family-year":
          "43c7f7b90140e9b0a5175bb733c43d7c96e37d45136d2939d98a4a8d77120008",
      "around-our-table":
          "39939f392c829736c1865bc50daab5d85546a64fa60900eb7aa5e1a6d859e435",
      "our-good-company":
          "6505a8ca7876ef16404df87a101d4df5a6da14a42cf3ef04bd77c49d4f322674",
      "across-generations":
          "d187ee6d1be999abccdefa9a33bd96221b6a9c932cb210454faeff98233bd142",
      "a-picnic-together":
          "188e90448205979f5af0d910d3b99976236a8affd97991c3fd144122504e6b1b",
      "dates-of-us":
          "66fa77ce3a4ea88d04015d89a36f21be439b1db9be4595928c01a29ed95a2a58",
      "scenes-for-two":
          "2cc0826446704296b8c183f42d95b0158698a8c0a791efaeabda89abbe7468bf",
      "seasons-of-love":
          "98aec300f903b79e1242a2a4fb2823628b6bdb6a5e9172f1d74d6089dd115833",
      "still-us":
          "87d72b6c6d0ef6b79ad82f291dbd8cc6c7b8c68b9f025fab8528e706ccd33fb2",
      "collected-by-two":
          "0cf28dc2da587bf61259b29e1281a4fa133b1f5e755283b51e7dd6e50de6b740",
      "a-day-with-you":
          "89d10d171cf2d656d0472c56b1b4dbf203f023b2ff4a8d387ecfa2c9739d19b9",
      "shapes-of-naps":
          "9a80088e82f8e22d197b1c2996364db4f4c2709de00f40d2ae2fc4a7138bebe3",
      "our-walking-promise":
          "92bb7f57224945ac1af4797377685eb24a3984d279a3155b93cd367847c485e9",
      "our-little-companion":
          "c03cf56bf80fe0ba9cf16d61c1e4bcbb73e43afbaed6ceec1e8c6bad483cb13c",
      "the-kindest-face":
          "4a4f85a8b7ad02cf9ba2c814970ac8f9c1c764d47ad4987279e016c87e336c38",
      "wind-atlas":
          "df77a514f91a4b9751f49fd7db7b699376fb55aa261fd6f1aa635ca57313495e",
      "our-prose":
          "729496bf4cfd07398d8a2e0a1347f752d7d9cba37f68a396bce8c9515d03446f",
      "alley-afternoon":
          "bcd49ea2c6072271aba1584f5aa6b8721bf8168da4c2a6c3b67e83b7331c2310",
      "saturday-together":
          "5010cd9a06764f587879f9f59b88f5fc735e93a30c22e7fe7ae80390654fa194",
      "daily-paw-walk":
          "006e6b6ead1a6bb717b17ef495ed6c5fb176626cff99e9142b67d2729716e1a1",
      "our-first-promise":
          "b60dc18c928e216cb2294e9e40d89e39949b196f9e6addb6e9622cb2c2c0baad",
      "little-day-discoveries":
          "5611a97ea9db57c6952a582c84be67fabab33cb59365b3a9d27bdc52809b637a",
    },
  },
  "landscape": {
    "protected":
        "b02b6d8379e9204822dcce885e683cc1dff5cf3eb1cb17f5de9ff439e8ba2bfd",
    "covers": {
      "lightbound":
          "7f434b84e13aaec767896782e20b57096d03de26d3429caacbd80ac44b586ae7",
      "journey":
          "ccd49cf8a584bee50af84233372b7619ab6fd975b9f47720192d6afd6cc0c382",
      "small-days":
          "323059e09ccf88913fa497961ecfc97cd0b916eebc8bb6ad9228bc871d4ae208",
      "our-vows":
          "90a4d9d28d93764cea950784df3d90dc5da41710db4096defdcd5a4edc87c3f7",
      "garden-promise":
          "7b711834d7bebf270a7d5d3860095bdc37208c790d1aa092eb9937db2bb505f0",
      "one-fine-film":
          "72e95cb70d1f01634901a13a8b0f817dcd474b1f035d1754e89729f8119b9dbb",
      "love-letters":
          "0a13113a766606022e9e031df366f9224b586c9318ed1130b346525856156df2",
      "across-the-sea":
          "72c05e8261838d8df25247b5bd79eb3012d543bc8eb3fc72a6c3609749a12c87",
      "city-collector":
          "7d9c608ee42582ff082c11632219a645cbce0af0ced113fb797b6e570f1a3136",
      "slow-paths":
          "ee6fe8fcc6aa8f71cc7f1925349eb008dace53ef120568d510c41ce66f1c10f7",
      "travel-postbox":
          "ca590649482bc1fd87d33de51b6ccc7d815188ffbdab8ca780e82d0c80e86935",
      "seasonal-table":
          "9644aeafe3a182d90b18f49b4211bf0a50a38fe282ed4dc0bee2145d30a7d503",
      "taste-archive":
          "255a6c167ee382c08422a35140533ee0755963643e1be6be6d23849ae71a2a50",
      "better-together":
          "812705a94b479e575249af154ba83d0945b02627dc138ceb3a930e6089feb1cc",
      "weekend-temperature":
          "939499f6794109083611b385632f3b27f7424f7948bdd2c3e129b33b29a8736c",
      "your-first-year":
          "2bf2eca095597ab585bf83b90ee9ba5d5a1a626a18383097242089ec8b24a9eb",
      "little-footsteps":
          "015ebe69c471426ad23d0f3f4471b7e82fac074da6060df4235eecfa93ab75fc",
      "you-are-spring":
          "692048149b9eb17f2c516c72d01618d15e6730a7cb6612a232eee6d78fe85784",
      "growing-in-color":
          "432a60af787850fcafd2b849b96d4ae91f07cad378e7675db59833d3e5c7ee1f",
      "first-birthday":
          "5849c49386996364ca6d621d8162123829cf02819288ee13e4f611b660e8c4d3",
      "our-family-year":
          "8753d59ab93345198d7060d9edf8a4e83903156b5931af18fcc35dcce3b465c8",
      "around-our-table":
          "22b6edeeed01b83577511f9caf081f09475204cc2e8eed170a0144846f5bec29",
      "our-good-company":
          "a5a47f6cef2d31b5f3ee3ede58558e75a80814171784872ff50c8ab0b77499fe",
      "across-generations":
          "4da24af9c41272c457a7a9b038fae2faa09fcd72b31e3a553b21502f44f8eb25",
      "a-picnic-together":
          "640f080a1d5eebd08be332bcd1b2e0792c1b838cd4fe6805c98c0864c8b47992",
      "dates-of-us":
          "9319a9b0c32ca30aaaa7211e6182f1981fb7dcd5f9e2d95c4dca8156da7495d2",
      "scenes-for-two":
          "8305fbd5fc86b468625f350739a49191dcbbbdb716e547cab68f8011177879a0",
      "seasons-of-love":
          "582770569a2677924b410e2848c042ecffb766250aac4ce4061fffcea1861a47",
      "still-us":
          "2b87930fe2b56c92eead0acf497fc15e9cca141ea724e7e35ae2f22864a792d7",
      "collected-by-two":
          "5a3dc0ecd45dcfd6c97dc40e2dc1f61d0fc67d0e7e54f17cee217a8170badaa9",
      "a-day-with-you":
          "0b973ec07bd39994e7c645cc9a55aaabf500fa97b108e295f9431107ce266bea",
      "shapes-of-naps":
          "7e34836c6798982f7f8594399a537d06494eac161513dee2b39fe45eef18bbf9",
      "our-walking-promise":
          "78a6c70cacfaf0e5e771a42d635e608740d461b587505bb4230a347079bba137",
      "our-little-companion":
          "e6cff72296c0ea411b213d47ad2245b858caf87f94cfc44590f7fdb9420a3be3",
      "the-kindest-face":
          "f01fb72a6ca1afd8714f029d8f64f5a898c2329c3357e2d2df6dc696c0b232c6",
      "wind-atlas":
          "3a37d3125fd1bbd1f7deda6795f6fc79fc4d6b4df3cb05e76c255dac4d5d96f9",
      "our-prose":
          "f4fa7889c7a8b309d522bda37c9621bf991e9495dfe16074db14567a80540877",
      "alley-afternoon":
          "e2922446d42e01942d1be794612726866ad4fbb0c171daf029b8ef0a09b16bcf",
      "saturday-together":
          "f5a57b916dc8bf63e6aee0991056e92bf0dd2d8078727d47e84a527ddcc75faf",
      "daily-paw-walk":
          "961f8a9921ebecee0cac3a739fa8bf59eafa8fee8fe97dbbef5496e3c39ab611",
      "our-first-promise":
          "91886f842b89f351452b8648d614e1693809a07cbe52276aaa109114de425589",
      "little-day-discoveries":
          "d386dace7b1808b5e1a09ef50eeba37b34b612aceb876301ea00ae14704832ea",
    },
  },
};

Object? _canonical(Object? value) {
  if (value is Map) {
    final keys = value.keys.cast<String>().toList()..sort();
    return {for (final key in keys) key: _canonical(value[key])};
  }
  if (value is List) return value.map(_canonical).toList();
  return value;
}

String _digest(Object? value) =>
    sha256.convert(utf8.encode(jsonEncode(_canonical(value)))).toString();

Map<String, dynamic> _protected(Map<String, dynamic> document) => {
  for (final key in const [
    'id',
    'collectionId',
    'editionId',
    'title',
    'category',
    'aiGenerated',
    'accessTier',
    'publicationStatus',
    'innerPageCount',
    'aspect',
    'designWidth',
    'designHeight',
    'chapters',
    'pages',
  ])
    if (document.containsKey(key)) key: document[key],
};

// Catalog presentation now includes newly authored interiors as well as covers.
// These original builders remain the compatibility reference for saved albums.
Map<String, dynamic> _sourceDocument(
  AuthoredCollection collection,
  CollectionAspect aspect,
) => switch (collection.id) {
  'lightbound' => buildLightboundWeddingDraft(aspect),
  'journey' => EditorialVolume.journey.document(aspect),
  'small-days' => EditorialVolume.smallDays.document(aspect),
  windAtlasId => buildWindAtlas(aspect),
  proseStudyId => buildProseAlbum(aspect),
  _ =>
    FreeCollectionVolume.byId(collection.id)?.document(aspect) ??
        StudioEdition.byId(collection.id)!.document(aspect),
};

Map<String, dynamic>? _fingerprintCache;
Map<String, dynamic> _fingerprints() => _fingerprintCache ??= {
  for (final aspect in CollectionAspect.values)
    aspect.name: {
      'protected': _digest({
        for (final collection in authoredCollections)
          collection.id: _protected(_sourceDocument(collection, aspect)),
      }),
      'covers': {
        for (final collection in authoredCollections)
          collection.id: _digest(collection.document(aspect)['cover']),
      },
    },
};

Future<void> _loadFonts() async {
  final manifest =
      jsonDecode(await rootBundle.loadString('FontManifest.json')) as List;
  for (final entry in manifest.whereType<Map>()) {
    final family = entry['family'] as String;
    final loader = FontLoader(family);
    for (final font in (entry['fonts'] as List).whereType<Map>()) {
      loader.addFont(rootBundle.load(font['asset'] as String));
    }
    await loader.load();
    _loadedFontFamilies.add(family);
  }
}

TextPainter _measure(LayerModel layer) => TextPainter(
  text: TextSpan(text: layer.text, style: layer.textStyle),
  textAlign: layer.textAlign ?? TextAlign.left,
  textDirection: TextDirection.ltr,
  strutStyle: StrutStyle.fromTextStyle(
    layer.textStyle!,
    forceStrutHeight: true,
  ),
)..layout(maxWidth: layer.width);

Rect _rect(LayerModel layer) =>
    layer.position & Size(layer.width, layer.height);

Rect _paintBounds(LayerModel layer) {
  final radians = layer.rotation * math.pi / 180;
  return Rect.fromCenter(
    center: _rect(layer).center,
    width:
        layer.width * math.cos(radians).abs() +
        layer.height * math.sin(radians).abs(),
    height:
        layer.width * math.sin(radians).abs() +
        layer.height * math.cos(radians).abs(),
  );
}

LayerModel _roundTrip(LayerModel layer, Size canvas) =>
    LayerExportMapper.fromJson(
      Map<String, dynamic>.from(
        jsonDecode(
              jsonEncode(
                LayerExportMapper.toJson(
                  layer,
                  canvasSize: canvas,
                  isCover: true,
                ),
              ),
            )
            as Map,
      ),
      canvasSize: canvas,
      isCover: true,
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(_loadFonts);

  if (_record) {
    test('record the shipping factory as hashes only', () {
      expect(authoredCollections, hasLength(42));
      // ignore: avoid_print
      print('SNAPFIT_FREE_CATALOG_BASELINE_V1:${jsonEncode(_fingerprints())}');
    });
    return;
  }

  test('all 42 free identities, prices, page counts and variants survive', () {
    expect(authoredCollections, hasLength(42));
    expect({
      for (final c in authoredCollections) c.id: c.bundledId,
    }, _catalogIds);
    expect(authoredCollections.map((c) => c.id).toSet(), hasLength(42));
    expect(authoredCollections.map((c) => c.bundledId).toSet(), hasLength(42));
    for (final collection in authoredCollections) {
      final template = bundledCreationTemplates.singleWhere(
        (item) => item.id == collection.bundledId,
      );
      final key = pointShopAuthoredTemplateKey(collection);
      expect(template.isPremium, isFalse, reason: collection.id);
      expect(pointShopTemplateKey(template), key);
      expect(pointShopRequiresFreePrice(key), isTrue);
      expect(pointShopLaunchPrices[key]!.points, 0);
      expect(template.pageCount, collection.id == windAtlasId ? 32 : 24);
      final catalog = jsonDecode(template.templateJson!) as Map;
      expect(
        (catalog['variants'] as Map).keys,
        unorderedEquals(CollectionAspect.values.map((a) => a.name)),
      );
      for (final aspect in CollectionAspect.values) {
        final document = collection.document(aspect);
        expect(document['aiGenerated'], isFalse);
        expect(document['innerPageCount'], template.pageCount);
        expect(document['pages'], hasLength(template.pageCount));
        expect(
          freeTemplateMaterialIssues(document),
          isEmpty,
          reason: '${collection.id}/${aspect.name}',
        );
        expect(catalog['variants'][aspect.name], document);
      }
    }
  });

  for (final aspect in CollectionAspect.values) {
    test(
      '${aspect.name}: photographed subjects retain readable unboxed title placement',
      () {
        Map<String, dynamic> coverFor(String id) =>
            authoredCollections
                    .singleWhere((c) => c.id == id)
                    .document(aspect)['cover']
                as Map<String, dynamic>;
        Map titleFor(String id) => (coverFor(id)['layers'] as List)
            .cast<Map>()
            .firstWhere((l) => l['typographyRole'] == 'signature-title');
        for (final id in ['taste-archive', 'little-footsteps', 'still-us']) {
          final title = titleFor(id);
          final value = (title['style'] as Map)['color'] as String;
          final color = Color(
            int.parse(value.replaceFirst('#', '').padLeft(8, 'F'), radix: 16),
          );
          expect(
            color.computeLuminance(),
            greaterThan(.8),
            reason: '$id: a dark photographed subject needs light title ink',
          );
        }
        for (final id in [
          'seasons-of-love',
          'you-are-spring',
          'our-good-company',
          'our-family-year',
        ]) {
          expect(
            titleFor(id)['y'] as num,
            lessThan(.3),
            reason: '$id: title uses the clear sky or linen above the subject',
          );
        }
        final company = titleFor('our-good-company');
        final companyInk = Color(
          int.parse(
            ((company['style'] as Map)['color'] as String)
                .replaceFirst('#', '')
                .padLeft(8, 'F'),
            radix: 16,
          ),
        );
        expect(
          companyInk.computeLuminance(),
          lessThan(.2),
          reason: 'The clear blue sky uses dark title ink',
        );
        final family = titleFor('our-family-year');
        expect(family['align'], 'center');
        expect(
          (family['x'] as num).toDouble() + (family['w'] as num).toDouble() / 2,
          closeTo(.5, .001),
        );
        if (aspect == CollectionAspect.landscape) {
          expect(family['text'], '우리 집의\n사계절');
          expect((family['style'] as Map)['fontSize'], 28.0);
          expect(family['x'] as num, greaterThanOrEqualTo(.34));
          expect(
            (family['x'] as num) + (family['w'] as num),
            lessThanOrEqualTo(.66),
            reason: 'The heading stays between both parents, above their child',
          );
          expect((family['y'] as num) + (family['h'] as num), lessThan(.26));
        } else {
          expect(family['text'], '우리 집의\n사계절');
          expect(family['w'] as num, lessThanOrEqualTo(.5));
        }
        final walk = titleFor('daily-paw-walk');
        expect(
          walk['text'],
          '오늘도\n산책!',
          reason: 'Break between words instead of splitting 산책',
        );
        expect(
          (walk['editorialSourceText'] as String).replaceAll(
            RegExp(r'\s+'),
            ' ',
          ),
          '오늘도 산책!',
        );
        final anniversary = titleFor('still-us');
        expect(anniversary['text'], '오래도록 우리');
        expect(
          (anniversary['editorialSourceText'] as String).replaceAll(
            RegExp(r'\s+'),
            ' ',
          ),
          '오래도록 우리',
        );
        expect(
          (anniversary['style'] as Map)['fontSize'] as num,
          lessThanOrEqualTo(34),
        );
      },
    );

    test('${aspect.name}: source personal bylines and dates fit longer copy', () {
      const longCopy = EditorialCopy(
        place: '북쪽 바다를 지나 작은 골목에서 만난 도시의 기록',
        period: '2026년 6월 12일 — 2026년 6월 18일',
        byline: '수연과 지후 / OUR SHARED MEMORIES',
        note: '사진 밖에 남은 이야기도 천천히 기록한다.',
      );
      const emptyCopy = EditorialCopy(
        place: '',
        period: '',
        byline: '',
        note: '',
      );
      for (final volume in FreeCollectionVolume.values) {
        for (final copy in [longCopy, emptyCopy]) {
          final document = volume.document(aspect, copy: copy);
          final layers = DataTemplateEngine.buildLayersFromJson(
            Map<String, dynamic>.from(document['cover'] as Map),
            aspect.canvas,
          );
          final text = layers
              .where((l) => l.type == LayerType.text)
              .map((l) => l.text ?? '')
              .join(' ')
              .replaceAll(RegExp(r'\s+'), ' ');
          for (final value in [copy.byline, copy.period]) {
            if (value.isNotEmpty)
              expect(
                text,
                contains(value),
                reason: '${volume.id}/${aspect.name}: personal field lost',
              );
          }
          for (final layer in layers.where((l) => l.type == LayerType.text)) {
            if ((layer.text ?? '').isEmpty) continue;
            final painter = _measure(layer);
            expect(
              painter.height,
              lessThanOrEqualTo(layer.height + .5),
              reason:
                  '${volume.id}/${aspect.name}/${layer.id}: long-copy overflow',
            );
            expect(
              painter.computeLineMetrics().every(
                (line) => line.width <= layer.width + .5,
              ),
              isTrue,
              reason: layer.id,
            );
            painter.dispose();
            expect(
              layer.textStyle!.fontSize,
              greaterThanOrEqualTo(8.5),
              reason: '${layer.id}: do not hide long fields by shrinking them',
            );
          }
        }
      }
    });

    test(
      '${aspect.name}: archived interiors and source identities are untouched',
      () {
        expect(
          _baseline,
          isNotEmpty,
          reason: 'Record the original factory before installing new covers.',
        );
        final actual = _fingerprints()[aspect.name] as Map;
        final original = _baseline[aspect.name] as Map;
        expect(
          actual['protected'],
          original['protected'],
          reason:
              'Saved-album source builders retain all 42 original interiors '
              'and identities while the current catalog evolves.',
        );
        for (final collection in authoredCollections) {
          expect(
            (actual['covers'] as Map)[collection.id],
            isNot((original['covers'] as Map)[collection.id]),
            reason:
                '${collection.id}: every current jacket uses the photographic edition',
          );
        }
      },
    );

    test(
      '${aspect.name}: 42 covers fit, keep photography open and remain editable',
      () {
        final fontFamilies = <String>{};
        for (final collection in authoredCollections) {
          final document = collection.document(aspect);
          expect(
            document['coverRevision'],
            'open-photographic-type-2026-10-21',
          );
          final cover = document['cover'] as Map<String, dynamic>;
          expect(cover['coverRevision'], document['coverRevision']);
          expect(cover['coverTextTreatment'], 'open-photographic-type');
          expect(cover['typographyPanelCoverageFraction'], 0.0);
          final heroArea = (cover['layers'] as List)
              .where((l) => l['type'] == 'image')
              .map(
                (l) => (l['w'] as num).toDouble() * (l['h'] as num).toDouble(),
              )
              .fold(0.0, math.max);
          expect(
            heroArea,
            greaterThanOrEqualTo(.8),
            reason:
                '${collection.id}/${aspect.name}: photography must lead the cover',
          );
          final layers = DataTemplateEngine.buildLayersFromJson(
            cover,
            aspect.canvas,
          );
          final prefix = '${collection.id}/${aspect.name}';
          final photoIndex = layers.indexWhere(
            (l) => l.type == LayerType.image,
          );
          expect(photoIndex, greaterThanOrEqualTo(0), reason: prefix);
          expect(
            layers
                .skip(photoIndex + 1)
                .where(
                  (l) => l.type != LayerType.image && l.type != LayerType.text,
                ),
            isEmpty,
            reason:
                '$prefix: no title plates, photo scrims or substitute panels',
          );
          expect(
            layers.where((l) => l.type == LayerType.text),
            isNotEmpty,
            reason: '$prefix: title must remain real editable text',
          );
          expect(layers.map((l) => l.id).toSet(), hasLength(layers.length));
          final cleared = AlbumCreationTemplate.preparePages(
            [layers],
            sourceCanvas: aspect.canvas,
            cover: aspect.cover,
          ).single;
          var largestType = 0.0;
          for (final (index, layer) in layers.indexed) {
            final label = '$prefix/${layer.id}';
            final bounds = _rect(layer);
            expect(bounds.isFinite, isTrue, reason: label);
            expect(bounds.width, greaterThan(0), reason: label);
            expect(bounds.height, greaterThan(0), reason: label);
            final painted = _paintBounds(layer);
            expect(painted.left, greaterThanOrEqualTo(-.5), reason: label);
            expect(painted.top, greaterThanOrEqualTo(-.5), reason: label);
            expect(
              painted.right,
              lessThanOrEqualTo(aspect.canvas.width + .5),
              reason: label,
            );
            expect(
              painted.bottom,
              lessThanOrEqualTo(aspect.canvas.height + .5),
              reason: label,
            );
            final restored = _roundTrip(layer, aspect.canvas);
            expect(restored.id, layer.id, reason: label);
            expect(restored.type, layer.type, reason: label);
            expect(restored.position.dx, closeTo(layer.position.dx, .001));
            expect(restored.position.dy, closeTo(layer.position.dy, .001));
            expect(restored.width, closeTo(layer.width, .001));
            expect(restored.height, closeTo(layer.height, .001));
            expect(restored.rotation, layer.rotation);
            expect(restored.opacity, layer.opacity);
            if (layer.type == LayerType.text) {
              expect(restored.text, layer.text, reason: label);
              expect(
                restored.textStyle!.fontFamily,
                layer.textStyle!.fontFamily,
              );
              expect(
                _loadedFontFamilies,
                contains(layer.textStyle!.fontFamily),
                reason: '$label: font must be bundled rather than substituted',
              );
              fontFamilies.add(layer.textStyle!.fontFamily!);
              final size = layer.textStyle!.fontSize!;
              expect(size, greaterThanOrEqualTo(8.5), reason: label);
              largestType = math.max(largestType, size);
              final painter = _measure(layer);
              expect(
                painter.height,
                lessThanOrEqualTo(layer.height + .5),
                reason: '$label: ${layer.text}',
              );
              expect(
                painter.computeLineMetrics().every(
                  (line) => line.width <= layer.width + .5,
                ),
                isTrue,
                reason: '$label: width overflow',
              );
              painter.dispose();
              expect(layer.textFillMode, 'solid', reason: label);
              final shadows = layer.textStyle!.shadows;
              expect(
                shadows,
                isNotEmpty,
                reason: '$label: restrained photographic type shadow',
              );
              for (final shadow in shadows!) {
                expect(
                  shadow.color.r + shadow.color.g + shadow.color.b,
                  0,
                  reason: '$label: no colored glow',
                );
                expect(shadow.color.a, lessThanOrEqualTo(.45), reason: label);
                expect(
                  shadow.blurRadius,
                  inInclusiveRange(0, 3),
                  reason: label,
                );
                expect(
                  shadow.offset.distance,
                  lessThanOrEqualTo(1),
                  reason: label,
                );
              }
              expect(
                restored.textStyle!.shadows,
                shadows,
                reason: '$label: saved photos retain type treatment',
              );
              expect(
                _roundTrip(
                  layer.copyWith(text: '함께 걸었던 여름의 기록 / 2026'),
                  aspect.canvas,
                ).text,
                '함께 걸었던 여름의 기록 / 2026',
              );
            }
            if (layer.type == LayerType.image) {
              expect(cleared[index].hasImageSource, isFalse, reason: label);
              expect(restored.imageUrl, layer.imageUrl);
              final replaced = cleared[index].copyWith(
                imageUrl: 'asset:assets/snapfit_home_square.jpg',
              );
              final savedPhoto = _roundTrip(replaced, aspect.canvas);
              expect(
                savedPhoto.imageUrl,
                'asset:assets/snapfit_home_square.jpg',
              );
              expect(savedPhoto.imageBackground, layer.imageBackground);
            }
          }
          expect(
            largestType,
            greaterThanOrEqualTo(
              aspect == CollectionAspect.landscape ? 28 : 30,
            ),
            reason: '$prefix: title must read at store-card size',
          );
        }
        expect(fontFamilies, isNotEmpty);
      },
    );
  }
}
