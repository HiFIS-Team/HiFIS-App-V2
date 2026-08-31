import 'package:barcode_widget/barcode_widget.dart';
import 'package:flutter/material.dart';

import '../../core/api/client/api_exception.dart';
import '../../core/api/staff/staff_api.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_decorations.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/util/skeleton_delay.dart';
import '../../core/widgets/feedback/app_dialog.dart';
import '../../core/widgets/feedback/app_toast.dart';
import '../../core/widgets/feedback/skeleton.dart';
import '../../core/widgets/input/app_button.dart';
import '../../core/widgets/input/pressable.dart';
import '../../core/widgets/nav/phone_scaffold.dart';

/// 지점 출퇴근 QR 관리 — **MASTER 만** (2026-08-28)
///
/// 하는 일이 둘이다.
///
/// 1. **카운터에 붙일 QR 을 보여준다** — 화면을 캡처해 인쇄하면 된다
/// 2. **매장 인터넷을 등록한다** — 이 폰이 지금 쓰는 인터넷을 그 지점 것으로
///    찍어 둔다. 고정 QR 이라 사진만으로는 어디서든 읽히는데, 서버가 이 값과
///    맞춰 보고 매장에서 온 요청만 받는다
///
/// **등록은 반드시 그 지점에 가서, 매장 와이파이에 붙은 채로** 눌러야 한다.
/// 집에서 누르면 대표 집이 매장으로 등록된다.
class AttendanceQrAdmin extends StatefulWidget {
  const AttendanceQrAdmin({super.key, required this.branchId});

  final String branchId;

  @override
  State<AttendanceQrAdmin> createState() => _AttendanceQrAdminState();
}

class _AttendanceQrAdminState extends State<AttendanceQrAdmin>
    with SkeletonDelay<AttendanceQrAdmin> {
  ScanQr? _qr;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final qr = await BranchApi.scanQr(widget.branchId);
      if (!mounted) return;
      setState(() {
        _qr = qr;
        endLoad();
      });
    } catch (error) {
      if (!mounted) return;
      setState(endLoad);
      AppToast.show(context, messageOf(error));
    }
  }

  /// 지금 이 폰이 쓰는 인터넷을 이 지점 것으로 등록한다
  Future<void> _register() async {
    final ok = await showConfirmDialog(
      context,
      icon: Icons.wifi_rounded,
      title: '지금 이 인터넷을 등록할까요?',
      message:
          '지금 이 폰이 쓰는 인터넷이 ${_qr?.branchName ?? '이 지점'} 것으로 등록돼요.\n'
          '**매장 와이파이에 연결한 채로** 눌러야 해요 — '
          'LTE 나 집 와이파이로 누르면 그 인터넷이 매장으로 등록됩니다.',
      confirmLabel: '등록',
    );
    if (!ok || !mounted) return;
    try {
      final qr = await BranchApi.registerScanIp(widget.branchId);
      if (!mounted) return;
      setState(() => _qr = qr);
      AppToast.show(context, '이 인터넷을 등록했어요');
    } catch (error) {
      if (mounted) AppToast.show(context, messageOf(error));
    }
  }

  Future<void> _forget(String ip) async {
    final ok = await showConfirmDialog(
      context,
      icon: Icons.delete_outline_rounded,
      title: '이 인터넷을 지울까요?',
      message: '$ip 에서는 QR 이 안 찍히게 돼요.',
      confirmLabel: '지우기',
      destructive: true,
    );
    if (!ok || !mounted) return;
    try {
      await BranchApi.forgetScanIp(widget.branchId, ip);
      await _load();
      if (mounted) AppToast.show(context, '지웠어요');
    } catch (error) {
      if (mounted) AppToast.show(context, messageOf(error));
    }
  }

  @override
  Widget build(BuildContext context) {
    final qr = _qr;
    return PhoneDetailScaffold(
      title: '출퇴근 QR',
      child: ListView(
        padding: EdgeInsets.fromLTRB(
          20,
          PhoneDetailScaffold.topPadding,
          20,
          MediaQuery.paddingOf(context).bottom + 32,
        ),
        children: showSkeleton || qr == null
            ? [_skeleton()]
            : [_qrCard(qr), SizedBox(height: 16), _ipCard(qr)],
      ),
    );
  }

  Widget _skeleton() => SkeletonGroup(
    child: SkeletonCard(
      children: [
        Skeleton(width: 90, height: 13),
        SizedBox(height: 16),
        Skeleton(height: 220, radius: 16),
      ],
    ),
  );

  /// 인쇄할 QR — **화면을 캡처해서 뽑으면 된다**
  Widget _qrCard(ScanQr qr) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.fromLTRB(20, 20, 20, 22),
      decoration: AppDecorations.card(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('${qr.branchName} 카운터 QR', style: AppTextStyles.label),
          SizedBox(height: 4),
          Text(
            '이 화면을 찍어 인쇄한 뒤 카운터에 붙여 주세요.',
            style: AppTextStyles.caption.copyWith(height: 1.5),
          ),
          SizedBox(height: 18),
          Center(
            child: Container(
              padding: EdgeInsets.all(16),
              decoration: BoxDecoration(
                // QR 은 흰 바탕이어야 읽힌다 — 카드 색이 바뀌어도 여기는 흰색
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.gray100),
              ),
              child: BarcodeWidget(
                barcode: Barcode.qrCode(),
                data: qr.payload,
                width: 220,
                height: 220,
                drawText: false,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// 등록된 매장 인터넷 — 비어 있으면 **아무도 못 찍는다**
  Widget _ipCard(ScanQr qr) {
    final empty = qr.allowedIps.isEmpty;
    return Container(
      width: double.infinity,
      padding: EdgeInsets.fromLTRB(20, 20, 20, 20),
      decoration: AppDecorations.card(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: Text('매장 인터넷', style: AppTextStyles.label)),
              Text(
                '${qr.allowedIps.length}',
                style: AppTextStyles.label.copyWith(
                  color: AppColors.textTertiary,
                ),
              ),
            ],
          ),
          SizedBox(height: 4),
          Text(
            empty
                // 비어 있는 것이 곧 '아무도 못 찍는 상태'라 그렇게 적는다 —
                // '등록해 주세요' 로만 두면 지금 안 되는 줄을 모른다
                ? '아직 등록된 인터넷이 없어서 QR 이 안 찍혀요.'
                : '여기 적힌 인터넷에서만 QR 이 찍혀요.',
            style: AppTextStyles.caption.copyWith(
              height: 1.5,
              color: empty ? AppColors.error : AppColors.textSecondary,
            ),
          ),
          if (!empty) ...[
            SizedBox(height: 14),
            for (var i = 0; i < qr.allowedIps.length; i++) ...[
              if (i > 0) Divider(height: 1, color: AppColors.divider),
              Padding(
                padding: EdgeInsets.symmetric(vertical: 12),
                child: Row(
                  children: [
                    Icon(
                      Icons.wifi_rounded,
                      size: 16,
                      color: AppColors.textTertiary,
                    ),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        qr.allowedIps[i],
                        style: AppTextStyles.body2.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    Pressable(
                      onTap: () => _forget(qr.allowedIps[i]),
                      padding: EdgeInsets.all(6),
                      child: Icon(
                        Icons.close_rounded,
                        size: 16,
                        color: AppColors.textTertiary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
          SizedBox(height: 16),
          AppButton(label: '지금 이 인터넷 등록', filled: true, onTap: _register),
          SizedBox(height: 10),
          Text(
            '지점에 가서 매장 와이파이에 연결한 뒤 눌러 주세요. '
            '인터넷 회선이 바뀌면 QR 이 안 찍히니 그때 다시 누르면 돼요.',
            style: AppTextStyles.caption.copyWith(
              fontSize: 12,
              height: 1.5,
              color: AppColors.textTertiary,
            ),
          ),
        ],
      ),
    );
  }
}
