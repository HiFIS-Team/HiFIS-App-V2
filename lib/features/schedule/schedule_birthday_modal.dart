import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/api/client/api_exception.dart';
import '../../core/api/client/period.dart' show dateKey;
import '../../core/api/staff/birthday_api.dart';
import '../../core/data/current_user.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/widgets/feedback/app_dialog.dart';
import '../../core/widgets/feedback/app_toast.dart';
import '../../core/widgets/input/app_button.dart';
import '../../core/widgets/input/pressable.dart';

// ---------------------------------------------------------------------------
// 생일 축하 모달 — 생일 당일 앱을 열면 **생일자 말고 전원**에게 뜬다
// (2026-09-27 대표 요청). 이모지를 누르면 생일자에게
// `00님이 축하 이모지를 보냈어요!` 푸시가 간다.
//
// **하루 한 번**이다 — 닫으면 그날은 다시 안 뜬다. 이미 축하를 보낸 사람
// (다른 기기에서 보냈어도)은 서버가 `cheered` 로 알려 줘서 건너뛴다.
// ---------------------------------------------------------------------------

const _seenKey = 'birthday_modal_seen';

/// 이번 실행에서 이미 판단했는지 — 탭을 옮길 때마다 다시 뜨지 않게 한다
bool _shown = false;

/// 로그아웃할 때 되돌린다 (다음 사람이 켜면 다시 판단해야 한다)
void resetBirthdayModal() => _shown = false;

/// 오늘 생일인 사람이 있으면 모달을 띄운다 — **띄웠으면 true**
///
/// 못 받으면 조용히 넘어간다 — 이것 때문에 앱 진입이 막히면 안 된다.
Future<bool> showBirthdayModal(BuildContext context) async {
  if (_shown) return false;
  _shown = true;

  final List<BirthdayToday> people;
  try {
    people = [
      for (final p in await BirthdayApi.today())
        if (!p.cheered) p,
    ];
  } catch (_) {
    return false;
  }
  if (people.isEmpty || !context.mounted) return false;

  // 기기에 사람마다 따로 남긴다 — 같은 폰에 다른 사람이 로그인해도 그 사람은 본다
  final prefs = await SharedPreferences.getInstance();
  final key = '$_seenKey:${currentUser?.id}';
  final today = dateKey(DateTime.now());
  if (prefs.getString(key) == today) return false;
  await prefs.setString(key, today);

  for (final person in people) {
    if (!context.mounted) break;
    await showAppDialog<void>(context, (_) => _BirthdayCard(person: person));
  }
  return true;
}

/// 확인 팝업([showConfirmDialog])과 같은 틀 — 아이콘 동그라미 · 제목 · 본문
class _BirthdayCard extends StatefulWidget {
  const _BirthdayCard({required this.person});

  final BirthdayToday person;

  @override
  State<_BirthdayCard> createState() => _BirthdayCardState();
}

class _BirthdayCardState extends State<_BirthdayCard> {
  bool _sent = false;
  bool _busy = false;

  Future<void> _cheer() async {
    if (_sent || _busy) return;
    setState(() => _busy = true);
    try {
      await BirthdayApi.cheer(widget.person.id);
      if (!mounted) return;
      setState(() {
        _busy = false;
        _sent = true;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() => _busy = false);
      AppToast.show(context, messageOf(error));
    }
  }

  @override
  Widget build(BuildContext context) {
    final name = widget.person.name;
    return Container(
      width: dialogWidth(context, 320),
      padding: const EdgeInsets.fromLTRB(24, 26, 24, 20),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.cake_rounded, size: 28, color: AppColors.primary),
          ),
          const SizedBox(height: 16),
          Text(
            '오늘 $name님 생일이에요!',
            textAlign: TextAlign.center,
            style: AppTextStyles.title3,
          ),
          const SizedBox(height: 10),
          Text(
            _sent ? '$name님에게 축하를 보냈어요' : '이모지를 눌러 축하를 보내보세요',
            textAlign: TextAlign.center,
            style: AppTextStyles.body2.copyWith(color: AppColors.textSecondary),
          ),
          const SizedBox(height: 20),
          // 축하 이모지 — 누르면 생일자에게 푸시. 보낸 뒤에는 잠근다
          Pressable(
            onTap: _cheer,
            child: AnimatedScale(
              scale: _sent ? 1.15 : 1,
              duration: const Duration(milliseconds: 200),
              curve: Curves.easeOutBack,
              child: AnimatedOpacity(
                opacity: _busy ? 0.4 : 1,
                duration: const Duration(milliseconds: 120),
                child: Container(
                  width: 72,
                  height: 72,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: _sent
                        ? AppColors.primary.withValues(alpha: 0.12)
                        : AppColors.gray50,
                    shape: BoxShape.circle,
                  ),
                  child: const Text('🎉', style: TextStyle(fontSize: 36)),
                ),
              ),
            ),
          ),
          const SizedBox(height: 24),
          AppButton(label: '닫기', onTap: () => Navigator.pop(context)),
        ],
      ),
    );
  }
}
