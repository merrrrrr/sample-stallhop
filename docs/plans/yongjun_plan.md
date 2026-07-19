# Yong Jun — Build Plan (Stall Vendor role)

**Total estimate: ~68 h.** This is the largest of the three roles — the two
biggest files in the whole app are yours. Start early and work strictly top to
bottom; every step only uses things built in earlier steps.

**When you can start:** you do **not** need all of Phase 0. You need Mervin's
§0.1–§0.4 merged — `AppConstants`, the theme, `formatters.dart`, `Validators`,
`lib/models/`, `lib/widgets/` and `StorageService` — which is the milestone he
marks as **§0.4a**, about 16 h into his work rather than 25 h. The teaching
session happens there too.

Auth, security rules and seed data (his §0.5–§0.7) land while you are already
building steps 1–2, because your stub ViewModel does not talk to Firestore at
all. Given you have the largest workload of the three, waiting for the full
Phase 0 merge is the single most expensive mistake available to you.

You will essentially rebuild the taught slice as your steps 1–4, which is
deliberate — it is the part you have already been walked through.

**The rule:** never copy-paste from the reference repo. Read a file, close it,
type your own. If you can't explain a line in the Q&A, it shouldn't be in your
submission. When stuck for more than ~30 minutes, ask Mervin — but ask him to
**pair with you while you type**, not to write it for you.

---

## What "the vendor role" is

A vendor owns exactly **one stall**. They can:

1. create their stall (it starts `pending` until Justin's admin approves it)
2. open/close it and set a prep time
3. manage its menu — add, edit, photograph, toggle availability, delete
4. work the live order queue — see incoming orders, mark them ready
5. verify pickup by scanning the customer's QR code, then mark collected
6. cancel an order (which refunds the customer)
7. view earnings and withdraw

## Your files

```
lib/features/vendor/
├── repository/
│   ├── menu_repository.dart
│   ├── vendor_order_repository.dart
│   └── earnings_repository.dart
├── view_model/
│   ├── menu_management_vm.dart
│   ├── vendor_dashboard_vm.dart
│   ├── order_queue_vm.dart
│   ├── order_detail_vm.dart
│   └── earnings_vm.dart
└── view/
    ├── vendor_dashboard_page.dart      ⚠ 487 lines — the biggest file in the app
    ├── menu_management_page.dart
    ├── add_edit_item_page.dart         ⚠ 449 lines — the hardest file you own
    ├── order_queue_page.dart
    ├── order_detail_page.dart
    └── vendor_earnings_page.dart
```

## Things Mervin built that you use (don't rebuild these)

| What | Where | What you call |
|---|---|---|
| `MenuItem`, `Stall`, `FoodOrder`, `WalletTransaction` | `lib/models/` | `fromJson` / `toJson` / `copyWith` |
| `cloud_firestore` directly | — | `_db.collection(...).snapshots()` / `.get()` — there is no wrapper service |
| `StorageService` | `core/services/` | `uploadImage(file, path)` → URL |
| `OrderRepository` | `features/customer/repository/` | `updateStatus`, `cancelAndRefund`, `watchVendorOrders`, `listenToOrder` |
| `WalletRepository` | `features/customer/repository/` | `watchTransactions`, `withdraw` |
| `QrScannerPage` | `widgets/qr_scanner_widget.dart` | push it, await the scanned string |
| `EmptyState`, `LoadingIndicator` | `widgets/` | every list screen |
| `centsToRM`, `formatDateTime`, `timeAgo` | `core/utils/formatters.dart` | all money and dates |
| `Validators` | `core/utils/validators.dart` | all forms |
| `AppConstants` | `core/utils/constants.dart` | never type a collection name yourself |

**Important:** your order status changes and cancellations **delegate into
Mervin's `OrderRepository`**. You never write wallet balances yourself — all
the money logic stays in one transactional place. Be ready to explain *why*
that is (if refund logic existed in two files, they would drift apart, and one
of them would eventually reverse the wrong amount).

---

## How you build each slice: stub → UI → repository → real VM

Your work is grouped into five **slices**, four of them built UI-first:

| Slice | Steps | Order |
|---|---|---|
| Menu | 1–4 | stub VM → 2 pages → repository → real VM |
| Orders | 5–7 | stub VM → page → repository → real VM |
| Order detail | 8–9 | stub VM → page → real VM |
| Dashboard | 10–11 | stub VM → page → real VM |
| **Earnings** | 12 | **repository → VM → page** (money — see below) |

**The stub ViewModel is the whole trick.** Before you build a page, spend
fifteen minutes writing a ViewModel with the *real* class name, the *real*
getters and the *real* method signatures — but hardcoded data inside and no
Firestore at all:

```dart
/// STUB — delete the fake list in step 4, keep everything else.
class MenuManagementViewModel extends ChangeNotifier {
  final String stallId;
  MenuManagementViewModel(this.stallId);

  List<MenuItem> _fake = [
    MenuItem(itemId: 'm1', name: 'Nasi Lemak', price: 850, category: 'Rice',
             available: true,  /* ... */),
    MenuItem(itemId: 'm2', name: 'Teh Tarik',  price: 250, category: 'Drinks',
             available: false, /* ... */),
  ];

  List<MenuItem> get items => _fake;
  bool get isLoading => false;      // flip to true by hand to check your spinner

  Future<void> toggleAvailable(MenuItem item) async {}   // no-ops for now
  Future<void> delete(MenuItem item) async {}
}
```

Why this and not a hardcoded `List` inside the widget:

- The pages you write against this stub are the **final** pages. When step 4
  replaces the stub with the real stream-backed ViewModel, the pages do not
  change at all — same `context.watch<MenuManagementViewModel>()`, same
  getters. That is the difference between *integrating* and *rewriting*.
- It forces you to design the VM's API before you need its implementation,
  which is the part that is hard to change later.
- No Firebase, no emulator, no seed data. Hot reload is instant — which matters
  more to you than to anyone else on the team, because your two 12 h files are
  both pure layout work.
- Give the stub `isLoading`, an empty-list case and an error case from day one.
  Flip them by hand and check the page renders `LoadingIndicator` and
  `EmptyState` properly. Pages built on always-present fake data are exactly
  the pages that have no loading state when the real stream arrives.

**Delete the stub in the same commit that adds the real ViewModel.** A stub
that survives into the final submission is a bug and an obvious Q&A target.

### The exception: money is built logic-first

Earnings (step 12) runs the other way round — repository, then ViewModel, then
page — because `withdraw` moves real money out of a wallet balance. That code
gets written and unit-tested before any UI exists.

One more money-adjacent case inside an otherwise UI-first slice: step 6's
`cancelOrder` delegates into Mervin's `OrderRepository.cancelAndRefund`. Wire
and verify **that one method** the moment step 6 lands — place an order as a
customer, cancel it as the vendor, confirm the customer's wallet balance goes
back up by exactly the right amount. Do not leave it stubbed until step 7 with
the rest of the slice.

---

# STEP 1 — `menu_management_page.dart` (4 h)

**Renders:** loading spinner → `EmptyState` if no items → grouped list.

> **Stub first (15 min).** Write `MenuManagementViewModel` as the stub shown in
> "How you build each slice" above, then build this page and step 2 against it.
> No Firestore, no emulator. Because all three render states below come off the
> stub's `isLoading` / `items`, flip those by hand and confirm each state
> actually renders — that is the habit that keeps loading and empty states from
> being an afterthought in step 4.

- [ ] `ChangeNotifierProvider(create: (_) => MenuManagementViewModel(stallId))`
      wrapping the page body.
- [ ] Three render states in order: `if (vm.isLoading) return LoadingIndicator();`
      → `if (vm.items.isEmpty) return EmptyState(...)` → the list.
- [ ] Group items by `category` — a `Map<String, List<MenuItem>>` built in the
      build method is fine at this scale.
- [ ] Each row: thumbnail (`CachedNetworkImage`, with a placeholder icon when
      `imageUrl` is null), name, `centsToRM(item.price)`, and a `Switch` bound
      to `item.available` calling `vm.toggleAvailable(item)`.
- [ ] Tap a row → push `AddEditItemPage(item: item)` (step 2).
- [ ] Long-press or a menu → delete, behind an `AlertDialog` confirmation.
- [ ] `FloatingActionButton` → `AddEditItemPage()` with no item (add mode).

### Code for step 1

> ⚠️ **Two deliberate additions over the reference repo.** It renders one flat
> list with no category grouping, and its delete fires immediately from the
> popup menu with no confirmation. The bullets above ask for both — a menu of
> thirty items across five categories is unusable flat, and an accidental
> delete is unrecoverable. Build them; they are also easy marks to defend.

Provider at the top, private view underneath — the pattern for every page you
own:

```dart
class MenuManagementPage extends StatelessWidget {
  final String stallId;
  const MenuManagementPage({super.key, required this.stallId});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => MenuManagementViewModel(stallId),
      child: _MenuView(stallId: stallId),
    );
  }
}
```

The three render states, in this order — loading before empty, always, or an
empty list flashes the empty state for one frame while the stream is still
connecting:

```dart
final vm = context.watch<MenuManagementViewModel>();
return Scaffold(
  appBar: AppBar(title: const Text('Menu')),
  floatingActionButton: FloatingActionButton.extended(
    onPressed: () => Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => AddEditItemPage(stallId: stallId),   // no item = add mode
    )),
    icon: const Icon(Icons.add),
    label: const Text('Add item'),
  ),
  body: vm.isLoading
      ? const LoadingIndicator()
      : vm.items.isEmpty
          ? const EmptyState(
              icon: Icons.restaurant_menu,
              title: 'No menu items',
              subtitle: 'Tap "Add item" to create your first dish.',
            )
          : _GroupedMenuList(items: vm.items, vm: vm, stallId: stallId),
);
```

**Grouping** — a `Map` built in `build` is fine at this scale (a stall has
tens of items, not thousands):

```dart
Map<String, List<MenuItem>> _byCategory(List<MenuItem> items) {
  final map = <String, List<MenuItem>>{};
  for (final item in items) {
    final key = item.category.isEmpty ? 'Uncategorised' : item.category;
    map.putIfAbsent(key, () => []).add(item);
  }
  return map;
}
```

Render each entry as a header `Text(category, style: AppTextStyles.title)`
followed by its rows. Sorting the keys keeps the order stable between
rebuilds — without it the sections jump around as items are edited.

**Each row** is a `ListTile` with the availability switch inline:

```dart
ListTile(
  leading: /* CachedNetworkImage thumbnail, or an Icons.restaurant placeholder
              when item.imageUrl is null */,
  title: Text(item.name, style: AppTextStyles.title),
  subtitle: Text(centsToRM(item.price)),
  onTap: () => Navigator.of(context).push(MaterialPageRoute(
    builder: (_) => AddEditItemPage(stallId: stallId, item: item),  // edit mode
  )),
  trailing: Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Switch(
            value: item.available,
            onChanged: (_) => vm.toggleAvailable(item),
          ),
          Text(item.available ? 'Available' : 'Sold out',
              style: AppTextStyles.caption),
        ],
      ),
      PopupMenuButton<String>(
        onSelected: (value) async {
          if (value == 'edit') { /* push AddEditItemPage in edit mode */ }
          if (value == 'delete') await _confirmDelete(context, vm, item);
        },
        itemBuilder: (_) => const [
          PopupMenuItem(value: 'edit', child: Text('Edit')),
          PopupMenuItem(
            value: 'delete',
            child: Text('Delete', style: TextStyle(color: AppColors.error)),
          ),
        ],
      ),
    ],
  ),
)
```

**The confirmation**, which the reference repo omits:

```dart
Future<void> _confirmDelete(
    BuildContext context, MenuManagementViewModel vm, MenuItem item) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text('Delete ${item.name}?'),
      content: const Text(
          'This removes the item from your menu permanently. Orders that '
          'already contain it are not affected.'),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(false),
          child: const Text('Cancel'),
        ),
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(true),
          child: const Text('Delete',
              style: TextStyle(color: AppColors.error)),
        ),
      ],
    ),
  );
  if (confirmed == true) await vm.delete(item);
}
```

`showDialog<bool>` returns `null` when the user taps outside it, which is why
the check is `== true` and not just `if (confirmed)`. The second sentence of
the dialog matters: `OrderItem` copies the name and price at cart time, so
deleting a menu item never corrupts a placed order. Know that answer.

# STEP 2 — ⚠ `add_edit_item_page.dart` (12 h) — **the hardest file you own**

449 lines. One screen doing four hard things at once: a validated form, image
capture and upload, and two nested dynamic list editors. **Build it in the five
sub-steps below and get each working before starting the next.** Do not try to
write it in one pass.

> **Still on the step 1 stub.** Everything here except the image upload is pure
> local widget state — form controllers, validation, and the two nested list
> editors never touch Firestore at all. That is why this file, your single
> biggest time sink, can be built and finished before `MenuRepository` exists.
>
> Two exceptions to wire for real as you go rather than stubbing:
> - **2b's upload** uses Mervin's `StorageService.uploadImage`, which lands in
>   Phase 0 §0.2 — so it is available to you from day one. Use it for real; a
>   stubbed upload teaches you nothing and hides the permission and file-size
>   problems you want to find early.
> - **2e's save** calls `vm.addItem(...)` / `vm.updateItem(...)`, which are
>   no-ops on the stub. Build the whole save path — validate, upload, convert
>   Ringgit to cents, pop — and let the write itself be the one thing that does
>   nothing until step 4. Verify the cents conversion with a `debugPrint` now;
>   do not wait for Firestore to tell you it was wrong by a factor of 100.

**2a — the form shell (3 h)**
- [ ] `StatefulWidget` taking an optional `MenuItem? item` — null means add
      mode, non-null means edit mode. One screen, two modes; the app bar title
      and the save button label switch on it.
- [ ] `GlobalKey<FormState>` + `TextEditingController`s for name, description,
      price, category. In edit mode, seed the controllers from the passed item
      in `initState`.
- [ ] Validators: `Validators.required` for name, `Validators.price` for price.
      Price is typed in Ringgit ("7.50") and converted with `rmToCents` at save
      time — **the model stores cents**. Getting this wrong by a factor of 100
      is the classic bug here; test it.
- [ ] `dispose()` every controller.

**2b — image picking and upload (3 h)**
- [ ] `ImagePicker().pickImage(source: ...)` behind a bottom sheet offering
      camera and gallery. Store the result as a `File?` in state.
- [ ] Preview: the picked `File` if there is one, else the existing `imageUrl`
      via `CachedNetworkImage`, else a placeholder.
- [ ] On save, **if** a new file was picked, `StorageService().uploadImage(file,
      'stalls/$stallId/menu/$itemId.jpg')` and use the returned URL. Skip the
      upload when unchanged — don't re-upload the same image on every edit.
- [ ] Show a progress indicator during upload; uploads are slow on real
      connections and a frozen button looks like a crash.
- [ ] Test both camera and gallery **on Android**. ⚠ This is also the feature
      that hard-crashes on iOS without the `Info.plist` fix — that's step 14.

**2c — the customizations editor (3 h)**
- [ ] `customizations` is a `List<Map<String, dynamic>>` where each entry is
      `{"name": "Size", "options": ["Small", "Large"]}` — a single-select group.
- [ ] Held in local `setState` state (not a view model — it is transient form
      state that only matters until save).
- [ ] UI: a list of groups; each group has a name field and a chip-style list of
      options with add and remove; plus an "add group" button.
- [ ] Removing the last option in a group should remove the group.

**2d — the add-ons editor (2 h)**
- [ ] `addOns` entries are `{"name": "Extra egg", "price": 150}` — **price in
      cents**, again entered in Ringgit and converted.
- [ ] Simpler than 4c: a flat list of name + price rows with add and remove.

**2e — save (1 h)**
- [ ] Validate the form, upload the image if needed, then
      `_repository.addItem(...)` in add mode or `_repository.updateItem(
      item.copyWith(...))` in edit mode.
- [ ] `Navigator.pop()` on success; a `SnackBar` on failure. Disable the save
      button while in flight so a double-tap can't create two items.

### Code for step 2

**2a — state and the two modes.** `widget.item == null` is the only thing
distinguishing add from edit; derive everything else from it:

```dart
class _AddEditItemPageState extends State<AddEditItemPage> {
  final _formKey = GlobalKey<FormState>();
  final _repository = MenuRepository();
  final _storage = StorageService();

  late final TextEditingController _name;
  late final TextEditingController _description;
  late final TextEditingController _price;
  late final TextEditingController _category;

  final List<_CustomizationDraft> _customizations = [];
  final List<_AddOnDraft> _addOns = [];

  File? _pickedImage;
  String? _imageUrl;
  bool _saving = false;

  bool get _isEdit => widget.item != null;
}
```

⚠️ **The cents/Ringgit boundary lives in `initState` and `_save`, nowhere
else.** Seed the price controller by dividing, read it back by parsing — get
either direction wrong and you are off by 100×:

```dart
@override
void initState() {
  super.initState();
  final item = widget.item;
  _name = TextEditingController(text: item?.name ?? '');
  _description = TextEditingController(text: item?.description ?? '');
  _price = TextEditingController(
    text: item == null ? '' : (item.price / 100).toStringAsFixed(2),
  );
  _category = TextEditingController(text: item?.category ?? '');
  _imageUrl = item?.imageUrl;
  /* ...seed the customization and add-on drafts from item... */
}
```

**The draft classes** are the key idea in this file. A dynamic list of text
fields needs a stable `TextEditingController` per row — rebuild them in
`build` and every keystroke resets the cursor:

```dart
class _CustomizationDraft {
  final TextEditingController nameController;
  final TextEditingController optionsController;

  _CustomizationDraft({String name = '', String options = ''})
      : nameController = TextEditingController(text: name),
        optionsController = TextEditingController(text: options);

  void dispose() {
    nameController.dispose();
    optionsController.dispose();
  }
}

class _AddOnDraft {
  final TextEditingController nameController;
  final TextEditingController priceController;

  _AddOnDraft({String name = '', double price = 0})
      : nameController = TextEditingController(text: name),
        priceController = TextEditingController(
          text: price == 0 ? '' : price.toStringAsFixed(2),
        );

  void dispose() {
    nameController.dispose();
    priceController.dispose();
  }
}
```

Adding a row is `setState(() => _customizations.add(_CustomizationDraft()))`;
removing is `setState(() => _customizations.removeAt(i)..dispose())` — dispose
the removed draft or you leak a controller per deletion.

`dispose()` must walk **both** lists as well as the four named controllers:

```dart
@override
void dispose() {
  _name.dispose();
  _description.dispose();
  _price.dispose();
  _category.dispose();
  for (final c in _customizations) { c.dispose(); }
  for (final a in _addOns) { a.dispose(); }
  super.dispose();
}
```

**2b — image picking.** The bullets ask for a bottom sheet offering both
sources; the reference repo only wires gallery, so this is yours to add:

```dart
Future<void> _pickImage(ImageSource source) async {
  final picked = await ImagePicker().pickImage(
    source: source,
    maxWidth: 1024,        // resize before upload — a 12 MP phone photo is
    imageQuality: 80,      // ~4 MB and takes forever on food-court wifi
  );
  if (picked != null) {
    setState(() => _pickedImage = File(picked.path));
  }
}

void _showImageSourceSheet() {
  showModalBottomSheet<void>(
    context: context,
    builder: (ctx) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            leading: const Icon(Icons.camera_alt),
            title: const Text('Take a photo'),
            onTap: () {
              Navigator.of(ctx).pop();
              _pickImage(ImageSource.camera);
            },
          ),
          ListTile(
            leading: const Icon(Icons.photo_library),
            title: const Text('Choose from gallery'),
            onTap: () {
              Navigator.of(ctx).pop();
              _pickImage(ImageSource.gallery);
            },
          ),
        ],
      ),
    ),
  );
}
```

⚠️ Pop the sheet **before** calling `_pickImage`, not after — the picker opens
a platform activity, and leaving the sheet mounted underneath it produces a
stranded sheet when the user backs out. This is also the code path that
hard-crashes on iOS without step 14's `Info.plist` strings.

The preview is a three-way fallback: picked file → existing URL → placeholder.

```dart
Widget _imagePreview() {
  if (_pickedImage != null) return Image.file(_pickedImage!, height: 160);
  if (_imageUrl != null) return CachedNetworkImage(imageUrl: _imageUrl!, height: 160);
  return Container(
    height: 160,
    color: AppColors.surface,
    child: const Icon(Icons.add_a_photo, size: 40),
  );
}
```

**4c / 4d — the two editors.** Both are a `List` of drafts rendered with an
index, plus an "add" button. The simplification worth taking: represent a
group's options as **one comma-separated text field** rather than a chip
editor with per-option add/remove.

```dart
List<Map<String, dynamic>> _buildCustomizations() {
  return _customizations
      .where((c) => c.nameController.text.trim().isNotEmpty)
      .map((c) => {
            'name': c.nameController.text.trim(),
            'options': c.optionsController.text
                .split(',')
                .map((e) => e.trim())
                .where((e) => e.isNotEmpty)
                .toList(),
          })
      .toList();
}

List<Map<String, dynamic>> _buildAddOns() {
  return _addOns
      .where((a) => a.nameController.text.trim().isNotEmpty)
      .map((a) => {
            'name': a.nameController.text.trim(),
            'price': rmToCents(a.priceController.text) ?? 0,   // cents!
          })
      .toList();
}
```

The `.where(...isNotEmpty)` filters are what make step 2c's "removing the last
option removes the group" fall out for free — an empty name or an empty
options string simply doesn't survive into the saved map, so a half-filled row
the vendor abandoned is silently dropped rather than saved as a broken group.
If you prefer the chip UI from the bullet, build it on top of these same
drafts; `_buildCustomizations` doesn't change.

**2e — save.** Validate, upload only if changed, then branch on the mode:

```dart
Future<void> _save() async {
  if (!_formKey.currentState!.validate()) return;
  setState(() => _saving = true);
  try {
    var imageUrl = _imageUrl;
    if (_pickedImage != null) {          // skip the upload when unchanged
      imageUrl = await _storage.uploadImage(
        _pickedImage!,
        'stalls/${widget.stallId}/menu/'
            '${DateTime.now().millisecondsSinceEpoch}.jpg',
      );
    }
    final priceCents = rmToCents(_price.text) ?? 0;
    if (_isEdit) {
      await _repository.updateItem(widget.item!.copyWith(
        name: _name.text.trim(),
        description: _description.text.trim(),
        price: priceCents,
        category: _category.text.trim(),
        imageUrl: imageUrl,
        customizations: _buildCustomizations(),
        addOns: _buildAddOns(),
      ));
    } else {
      await _repository.addItem(
        stallId: widget.stallId,
        name: _name.text.trim(),
        /* ...same fields... */
      );
    }
    if (mounted) Navigator.of(context).pop();
  } catch (e) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Could not save item.'),
        backgroundColor: AppColors.error,
      ));
    }
  } finally {
    if (mounted) setState(() => _saving = false);
  }
}
```

The timestamp filename means an edited item's new photo never overwrites the
old one mid-flight — a viewer holding the previous URL keeps seeing a valid
image rather than a broken link.

The save button carries the in-flight state, which is the double-tap guard:

```dart
ElevatedButton(
  onPressed: _saving ? null : _save,
  child: _saving
      ? const SizedBox(
          height: 22, width: 22,
          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
        )
      : Text(_isEdit ? 'Save changes' : 'Add item'),
)
```

`onPressed: null` genuinely disables the button — don't rely on an `if
(_saving) return;` inside `_save`, because the button still looks tappable and
the vendor will tap it again during a slow upload.

# STEP 3 — `MenuRepository` (3 h)

`lib/features/vendor/repository/menu_repository.dart`

**What it does:** all reading and writing of a stall's menu items. Nothing else
in your role touches the menu collection directly.

**Firestore:** subcollection `stalls/{stallId}/menuItems/{itemId}`, built from
`AppConstants.stallsCollection` and `AppConstants.menuItemsSubcollection` —
never as a string literal.

- [ ] Constructor takes an optional `FirebaseFirestore? db` falling back to
      `FirebaseFirestore.instance`. **This is what makes your tests possible in
      step 13** — don't skip it. Every repository in the app has this one
      parameter and nothing else.
- [ ] One private `CollectionReference _col(String stallId)` helper that every
      other method builds on.
- [ ] `Stream<List<MenuItem>> watchMenuItems(String stallId)` —
      `_col(stallId).snapshots()` mapped through `MenuItem.fromJson(d.data())`
- [ ] `Future<MenuItem> addItem({required stallId, name, description, price,
      category, imageUrl, customizations, addOns})` — call `_col(stallId).doc()`
      **first** to generate the id, put that id inside the `MenuItem`, then
      `set`. *Why:* every StallHop document stores its own id as a field, so a
      raw data map is enough to rebuild the model. Return the created item.
- [ ] `Future<void> updateItem(MenuItem item)` — `set` the whole document from
      `item.copyWith(updatedAt: DateTime.now())`.
- [ ] `Future<void> setAvailable(stallId, itemId, bool available)` — a targeted
      `update` of just `available` and `updatedAt`. A separate method from
      `updateItem` because the availability toggle fires constantly and
      shouldn't rewrite the whole document.
- [ ] `Future<void> deleteItem(stallId, itemId)`

### Code for step 3

The constructor and the path helper — every other method is built on these:

```dart
class MenuRepository {
  final FirebaseFirestore _db;

  MenuRepository({FirebaseFirestore? db})
      : _db = db ?? FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> _col(String stallId) => _db
      .collection(AppConstants.stallsCollection)
      .doc(stallId)
      .collection(AppConstants.menuItemsSubcollection);

  Stream<List<MenuItem>> watchMenuItems(String stallId) {
    return _col(stallId).snapshots().map(
          (snap) => snap.docs.map((d) => MenuItem.fromJson(d.data())).toList(),
        );
  }
}
```

Note `.collection(...).doc(...).collection(...)` rather than a slash-joined
path string — the SDK builds the subcollection reference for you, and it can't
be typo'd into a malformed path.

⚠️ **`addItem` generates the id before building the model**, which is the
convention the whole app depends on:

```dart
Future<MenuItem> addItem({
  required String stallId,
  required String name,
  required String description,
  required int price,
  required String category,
  String? imageUrl,
  List<Map<String, dynamic>> customizations = const [],
  List<Map<String, dynamic>> addOns = const [],
}) async {
  final ref = _col(stallId).doc();      // id first...
  final now = DateTime.now();
  final item = MenuItem(
    itemId: ref.id,                     // ...so it can live inside the model
    stallId: stallId,
    name: name,
    description: description,
    price: price,
    category: category,
    imageUrl: imageUrl,
    customizations: customizations,
    addOns: addOns,
    createdAt: now,
    updatedAt: now,
  );
  await ref.set(item.toJson());
  return item;
}
```

Calling `.doc()` with no argument generates the id **locally, without a
network round-trip** — that is what lets the id be a field inside the document
it names. Every StallHop model does this, and it is why `fromJson` alone is
enough to rebuild a model from a raw data map with no `DocumentSnapshot` in
hand. Returning the created item saves the caller a read.

The three mutators, and why `setAvailable` is separate from `updateItem`:

```dart
Future<void> updateItem(MenuItem item) {
  return _col(item.stallId).doc(item.itemId).set(
        item.copyWith(updatedAt: DateTime.now()).toJson(),
      );
}

/// A targeted update, not a whole-document `set`. The availability switch
/// fires constantly during a service; rewriting every field each time would
/// clobber a concurrent edit from the add/edit screen.
Future<void> setAvailable(String stallId, String itemId, bool available) {
  return _col(stallId).doc(itemId).update({
    'available': available,
    'updatedAt': Timestamp.fromDate(DateTime.now()),
  });
}

Future<void> deleteItem(String stallId, String itemId) {
  return _col(stallId).doc(itemId).delete();
}
```

Note `updateItem` uses `set` (full replace) while `setAvailable` uses `update`
(merge specific fields). Be able to say why each is right where it is.

# STEP 4 — `MenuManagementViewModel` (2 h)

`view_model/menu_management_vm.dart`

> **This replaces your stub.** Same class name, same `items` / `isLoading`
> getters, same `toggleAvailable` / `delete` signatures — only the insides
> change, from a hardcoded list to a live subscription. Steps 1 and 2 should
> need **zero** edits. If either needs any, note what and why: that is the part
> of the API your stub got wrong, and it is worth saying out loud in the Q&A.
> Delete the stub file in this same commit.

**State:** `List<MenuItem> _items` (starts empty), `bool _loading` (starts
`true`). Exposed via `items` and `isLoading` getters — the fields stay private.

- [ ] Constructor takes `String stallId` and optional `MenuRepository?`, then
      immediately subscribes:
      `_sub = _repository.watchMenuItems(stallId).listen(onData, onError: ...)`
- [ ] In `onData`: set `_items`, set `_loading = false`, `notifyListeners()`.
- [ ] **In `onError`: `debugPrint` the error, set `_loading = false`,
      `notifyListeners()`.** Miss this and any Firestore permission problem
      leaves the screen spinning forever with no clue why. This is the single
      most common bug you will hit — Mervin demonstrated it deliberately in the
      teaching session.
- [ ] `toggleAvailable(MenuItem item)` → `_repository.setAvailable(stallId,
      item.itemId, !item.available)`. **No local state change** — the write goes
      to Firestore, the stream fires, the VM notifies, the UI rebuilds.
- [ ] `delete(MenuItem item)`
- [ ] `dispose()` → `_sub?.cancel()` then `super.dispose()`.

**Wire and verify before moving on (do not batch this up):**

- [ ] Seeded menu items appear from Firestore, grouped by category as designed.
- [ ] Toggle availability → the row updates **by itself**, because the stream
      re-fires. You are not calling `setState` anywhere.
- [ ] Add an item via step 2's page → it appears in the list without a manual
      refresh, and its image actually loads from Storage.
- [ ] Break a security rule deliberately → the spinner stops and you get a
      `debugPrint`, rather than spinning forever. This is the `onError` path,
      and it is the one thing your stub could not teach you.
- [ ] Delete every item → `EmptyState` renders, not a blank screen.

### Code for step 4

The entire class — it is short, and every view model you write after this one
is the same shape:

```dart
class MenuManagementViewModel extends ChangeNotifier {
  final MenuRepository _repository;
  final String stallId;
  StreamSubscription<List<MenuItem>>? _sub;

  List<MenuItem> _items = [];
  bool _loading = true;

  MenuManagementViewModel(this.stallId, {MenuRepository? repository})
      : _repository = repository ?? MenuRepository() {
    _sub = _repository.watchMenuItems(stallId).listen(
      (items) {
        _items = items;
        _loading = false;
        notifyListeners();
      },
      onError: (Object e) {
        debugPrint('MenuManagementViewModel stream error: $e');
        _loading = false;
        notifyListeners();
      },
    );
  }

  List<MenuItem> get items => _items;
  bool get isLoading => _loading;

  Future<void> toggleAvailable(MenuItem item) {
    return _repository.setAvailable(stallId, item.itemId, !item.available);
  }

  Future<void> delete(MenuItem item) {
    return _repository.deleteItem(stallId, item.itemId);
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }
}
```

⚠️ **`_loading = false` appears in the `onError` branch too.** This is the bug
Mervin demonstrated deliberately in the teaching session: if you only clear the
flag on success, a Firestore permission error leaves `isLoading` true forever
and the screen spins with no error, no log, and nothing to debug from. The
`debugPrint` is the other half — without it the failure is completely silent.

⚠️ **`toggleAvailable` changes no local state.** It writes to Firestore and
returns. The write lands, the snapshot stream fires, `onData` replaces
`_items`, `notifyListeners()` rebuilds the UI. Setting `item.available`
locally *as well* would give you a switch that flickers — once from your
optimistic update, once from the stream — and that drifts out of sync the
moment a write fails. One direction of data flow: write down, read up.

# STEP 5 — `order_queue_page.dart` (5 h)

> **Stub first (15 min).** Write `OrderQueueViewModel(vendorUid)` with
> `isLoading`, `preparing` and `ready` as hardcoded `List<FoodOrder>` (put three
> or four fake orders in each, with different `createdAt` values so you can see
> your oldest-first sort), and `markReady(order)` as a no-op. Steps 6 and 7
> replace the insides.

- [ ] `DefaultTabController` with two tabs, Preparing and Ready, showing the
      counts in the labels.
- [ ] Each order card: pickup code (large — it's the main identifier), customer
      name, item count, `centsToRM(order.total)`, and `timeAgo(order.createdAt)`.
- [ ] Preparing cards get a "Mark ready" button; ready cards get "Verify pickup"
      pushing the order detail (step 8).
- [ ] `EmptyState` per tab when it's empty.
- [ ] Watch it work: with two devices, a customer order should appear here
      **without any refresh** — that's the snapshot stream.

### Code for step 5

**The tab shell.** Counts go straight in the labels — a vendor glancing at the
phone across the counter needs the number without reading the list:

```dart
final vm = context.watch<OrderQueueViewModel>();
return DefaultTabController(
  length: 2,
  child: Scaffold(
    appBar: AppBar(
      title: const Text('Order queue'),
      bottom: TabBar(
        tabs: [
          Tab(text: 'Preparing (${vm.preparing.length})'),
          Tab(text: 'Ready (${vm.ready.length})'),
        ],
      ),
    ),
    body: vm.isLoading
        ? const LoadingIndicator()
        : TabBarView(
            children: [
              _OrderColumn(
                orders: vm.preparing,
                emptyTitle: 'No orders to prepare',
                primaryLabel: 'Mark ready',
                onPrimary: (o) => vm.markReady(o.orderId),
              ),
              _OrderColumn(
                orders: vm.ready,
                emptyTitle: 'No orders awaiting pickup',
                primaryLabel: 'Verify & complete',
                onPrimary: (o) => Navigator.of(context).push(MaterialPageRoute(
                  builder: (_) => VendorOrderDetailPage(orderId: o.orderId),
                )),
              ),
            ],
          ),
  ),
);
```

⚠️ **Write `_OrderColumn` once and parameterise it**, rather than two
near-identical tab bodies. The tabs differ in exactly three things — the list,
the empty message, and what the primary button does — so they become
constructor arguments:

```dart
class _OrderColumn extends StatelessWidget {
  final List<FoodOrder> orders;
  final String emptyTitle;
  final String primaryLabel;
  final void Function(FoodOrder) onPrimary;
}
```

Note the two `onPrimary`s are genuinely different in kind: Preparing performs
the state change inline (`vm.markReady`), while Ready *navigates* — because
completing an order requires the QR verification in step 8 and must never be a
one-tap action from a list.

**The card.** Pickup code first and largest; it is what the vendor shouts
across the counter:

```dart
Card(
  child: Padding(
    padding: const EdgeInsets.all(16),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('#${order.pickupCode}',
                style: AppTextStyles.h3.copyWith(color: AppColors.orange)),
            Text(timeAgo(order.createdAt), style: AppTextStyles.caption),
          ],
        ),
        const SizedBox(height: 4),
        Text(order.customerName, style: AppTextStyles.bodySecondary),
        const Divider(),
        for (final item in order.items)
          Text('${item.quantity}× ${item.name}', style: AppTextStyles.body),
        const SizedBox(height: 12),
        Row(children: [
          Expanded(child: OutlinedButton(/* Details -> detail page */)),
          const SizedBox(width: 12),
          Expanded(child: ElevatedButton(
            onPressed: () => onPrimary(order),
            child: Text(primaryLabel),
          )),
        ]),
      ],
    ),
  ),
)
```

`timeAgo(order.createdAt)` rather than a timestamp is deliberate — "12 min
ago" tells a vendor whether they are behind; "13:42" makes them do arithmetic.

Empty state per tab, not per page: `EmptyState(icon: Icons.inbox_outlined,
title: emptyTitle)` inside `_OrderColumn`, so Preparing can be empty while
Ready is not.

# STEP 6 — `VendorOrderRepository` (4 h)

`repository/vendor_order_repository.dart`. Two responsibilities: the vendor's
own **stall** document, and the **order queue** (which it delegates).

- [ ] Constructor takes optional `db`, `firestore`, **and `OrderRepository?`**.
- [ ] `Stream<Stall?> watchMyStall(String vendorUid)` — query `stalls` where
      `vendorUid == uid`, `.limit(1)`, map `rows.isEmpty ? null :
      Stall.fromJson(rows.first)`. *A vendor owns at most one stall, which is
      why `limit(1)` and a nullable single result rather than a list.*
- [ ] `Future<Stall?> getMyStall(String vendorUid)` — same query, one-shot.
- [ ] `Future<Stall> createStall({vendorUid, name, cuisine, description,
      prepTimeMinutes})` — generate the id first, `status:
      AppConstants.stallPending`. ⚠ **Write `commissionRate: null`**, not a
      hardcoded rate. `null` means "inherit the venue-wide default that the
      admin controls". *(This differs from the reference repo, which hardcodes
      0.10 here and thereby makes the admin's setting do nothing — see
      `foundation_and_integration.md` §6.1. Know this answer; it's a likely
      Q&A question.)*
- [ ] `updateStall(stallId, Map data)` — spreads the map and always stamps
      `updatedAt`.
- [ ] `setOpen(stallId, bool)` → status `open` or `closed`.
      `setPrepTime(stallId, int)`.
- [ ] **Orders — all delegated to Mervin's `OrderRepository`:**
      `watchActiveOrders(uid)` → `watchVendorOrders(uid, statuses: ['preparing',
      'ready'])`; `watchAllOrders(uid)`; `listenToOrder(orderId)`;
      `markReady(orderId)` → `updateStatus(id, 'ready')`;
      `markCollected(orderId)` → `updateStatus(id, 'collected')`;
      `cancelOrder(order)` → `cancelAndRefund(order)`.
      **You write no wallet code at all.**

### Code for step 6

**Two injectable dependencies**, and note `OrderRepository(db: db)` — the
same fake Firestore has to reach the delegated repository too, or your step 13
tests will hit the real backend through the back door:

```dart
class VendorOrderRepository {
  final FirebaseFirestore _db;
  final OrderRepository _orderRepository;

  VendorOrderRepository({
    FirebaseFirestore? db,
    OrderRepository? orderRepository,
  })  : _db = db ?? FirebaseFirestore.instance,
        _orderRepository = orderRepository ?? OrderRepository(db: db);

  CollectionReference<Map<String, dynamic>> get _stalls =>
      _db.collection(AppConstants.stallsCollection);
}
```

**The stall half.** `limit(1)` plus a nullable single result, because a vendor
owns at most one stall. Build the query once so the stream and one-shot reads
can't drift apart:

```dart
Query<Map<String, dynamic>> _myStallQuery(String vendorUid) =>
    _stalls.where('vendorUid', isEqualTo: vendorUid).limit(1);

Stream<Stall?> watchMyStall(String vendorUid) {
  return _myStallQuery(vendorUid).snapshots().map(
        (snap) =>
            snap.docs.isEmpty ? null : Stall.fromJson(snap.docs.first.data()),
      );
}
```

`null` is a real state here, not an error — it is what makes the dashboard show
the create-stall form instead of the dashboard. `getMyStall` is the same helper
with `.get()` instead of `.snapshots()`.

⚠️ **`createStall` writes no `commissionRate` at all:**

```dart
Future<Stall> createStall({
  required String vendorUid,
  required String name,
  required String cuisine,
  required String description,
  int prepTimeMinutes = 15,
}) async {
  final ref = _stalls.doc();
  final now = DateTime.now();
  final stall = Stall(
    stallId: ref.id,
    vendorUid: vendorUid,
    name: name,
    cuisine: cuisine,
    description: description,
    status: AppConstants.stallPending,
    prepTimeMinutes: prepTimeMinutes,
    // No commissionRate — the field is nullable and null means "inherit the
    // venue-wide default the admin controls". The reference repo hardcodes
    // AppConstants.defaultCommissionRate here, which is exactly why the
    // admin's setting never reaches pricing (foundation_and_integration.md
    // §6.1). A non-null value is an admin-only negotiated override.
    createdAt: now,
    updatedAt: now,
  );
  await ref.set(stall.toJson());
  return stall;
}
```

`status: AppConstants.stallPending` is what keeps the stall out of
`StallRepository.watchVisibleStalls()` until Justin's admin approves it.

The updates funnel through one method so `updatedAt` is stamped in exactly one
place:

```dart
Future<void> updateStall(String stallId, Map<String, dynamic> data) {
  return _stalls.doc(stallId).update({
    ...data,
    'updatedAt': Timestamp.fromDate(DateTime.now()),
  });
}

Future<void> setOpen(String stallId, bool open) => updateStall(stallId, {
      'status': open ? AppConstants.stallOpen : AppConstants.stallClosed,
    });

Future<void> setPrepTime(String stallId, int minutes) =>
    updateStall(stallId, {'prepTimeMinutes': minutes});
```

**The order half is six one-line delegations.** This is the part to be able to
defend — there is deliberately no logic here:

```dart
Stream<List<FoodOrder>> watchActiveOrders(String vendorUid) {
  return _orderRepository.watchVendorOrders(
    vendorUid,
    statuses: const [AppConstants.orderPreparing, AppConstants.orderReady],
  );
}

Stream<List<FoodOrder>> watchAllOrders(String vendorUid) =>
    _orderRepository.watchVendorOrders(vendorUid);

Stream<FoodOrder?> listenToOrder(String orderId) =>
    _orderRepository.listenToOrder(orderId);

Future<void> markReady(String orderId) =>
    _orderRepository.updateStatus(orderId, AppConstants.orderReady);

Future<void> markCollected(String orderId) =>
    _orderRepository.updateStatus(orderId, AppConstants.orderCollected);

Future<void> cancelOrder(FoodOrder order) =>
    _orderRepository.cancelAndRefund(order);
```

**Why this class exists at all if it just forwards:** it gives the vendor
feature one seam to inject in tests and one place to look for "what can a
vendor do to an order", without duplicating the transactional wallet code. If
`cancelOrder` contained its own refund logic, there would be two
implementations of a money reversal and they would drift — which is precisely
the bug §6.1 documents.

# STEP 7 — `OrderQueueViewModel` (2 h)

> **This replaces your step 5 stub.** Same getters, same `markReady` signature;
> `order_queue_page.dart` should need zero edits. Delete the stub in this commit.
>
> **Wire and verify immediately:** mark an order ready as the vendor and watch
> it move tabs on its own; then confirm the same change appears live on Mervin's
> customer order-tracking screen. And verify step 6's `cancelOrder` end to end —
> place an order as a customer, cancel it as the vendor, check the customer's
> wallet balance goes back up by exactly the right amount. That path moves money
> through `OrderRepository.cancelAndRefund`; do not leave it unverified.

- [ ] Subscribes to `watchActiveOrders(vendorUid)` in the constructor
      (`onError` handler — same as step 4).
- [ ] Two computed getters filtering the one list:
      `preparing` (status `preparing`) and `ready` (status `ready`), each
      **sorted oldest-first** — `..sort((a, b) => a.createdAt.compareTo(b.createdAt))`.
      Oldest first is correct for a kitchen queue; be ready to say why.
- [ ] `markReady(orderId)` delegating to the repository.
- [ ] `dispose()` cancels.

### Code for step 7

One subscription, two computed getters over the same list:

```dart
class OrderQueueViewModel extends ChangeNotifier {
  final VendorOrderRepository _repository;
  StreamSubscription<List<FoodOrder>>? _sub;

  List<FoodOrder> _orders = [];
  bool _loading = true;

  OrderQueueViewModel(String vendorUid, {VendorOrderRepository? repository})
      : _repository = repository ?? VendorOrderRepository() {
    _sub = _repository.watchActiveOrders(vendorUid).listen(
      (orders) {
        _orders = orders;
        _loading = false;
        notifyListeners();
      },
      onError: (Object e) {
        debugPrint('OrderQueueViewModel stream error: $e');
        _loading = false;
        notifyListeners();
      },
    );
  }

  bool get isLoading => _loading;

  List<FoodOrder> get preparing => _orders
      .where((o) => o.status == AppConstants.orderPreparing)
      .toList()
    ..sort((a, b) => a.createdAt.compareTo(b.createdAt));

  List<FoodOrder> get ready => _orders
      .where((o) => o.status == AppConstants.orderReady)
      .toList()
    ..sort((a, b) => a.createdAt.compareTo(b.createdAt));

  Future<void> markReady(String orderId) => _repository.markReady(orderId);

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }
}
```

Two things to be ready to explain:

- **`.toList()` before `..sort()`.** `where` returns a lazy `Iterable` with no
  `sort`, and sorting `_orders` in place would mutate the field the stream
  owns. `toList()` gives you a fresh list to reorder safely.
- **Oldest-first, not newest-first.** A kitchen queue is FIFO — the customer
  who has waited longest should be cooked next. Newest-first is the right
  default for a *history* list (which is why `watchVendorOrders` orders
  `createdAt` descending) and the wrong one for a work queue. This getter
  deliberately reverses the repository's ordering.

# STEP 8 — `order_detail_page.dart` (9 h)

Full order detail plus the **QR pickup verification** — the most interesting
screen you own and a good one to demo.

> **Stub first (15 min).** Write `VendorOrderDetailViewModel(orderId)` with
> `isLoading`, a `FoodOrder? order` returning one richly-populated fake order —
> give it several `OrderItem`s *with* customizations, add-ons and special
> instructions, because the item breakdown is the fiddly part of this page — and
> no-op `markReady` / `markCollected` / `cancel`. Step 9 replaces the insides.
>
> The QR scanner itself needs a real device and a real code, so leave the
> scan-result branch wired to a hardcoded string until step 9; build the layout
> and the success/failure states against that first.

- [ ] Header: pickup code, status chip, customer name, order time.
- [ ] Item breakdown — for each `OrderItem`: name, quantity, chosen
      `customizations`, selected `addOns`, `specialInstructions`, and
      `centsToRM(item.subtotal)`. Then subtotal, service fee, total.
- [ ] Status actions driven by the current status: `preparing` → "Mark ready";
      `ready` → "Scan to verify"; `collected` → no actions.
- [ ] **QR verification flow:**
      ```dart
      final scanned = await Navigator.push<String>(
        context, MaterialPageRoute(builder: (_) => const QrScannerPage()));
      if (scanned == null) return;                 // user dismissed
      if (scanned != order.pickupCode) { show "wrong code" SnackBar; return; }
      await vm.markCollected(order.orderId);
      ```
      Handle all three outcomes — dismissed, mismatch, match. A mismatch must
      fail loudly and clearly; this is the anti-fraud check of the whole app.
- [ ] Also offer manual code entry as a fallback for when a camera won't
      cooperate — you will be glad of this during the live demo.
- [ ] Cancel action behind an `AlertDialog` warning that the customer is
      refunded in full. Calls `vm.cancel(order)` → Mervin's `cancelAndRefund`.
- [ ] Test the scanner on a **physical Android device** — an emulator's fake
      camera cannot read a real QR code. Display the customer's code on a second
      device (or on your laptop screen) and scan it from the phone.
      ⚠ This screen also hard-crashes on iOS without the `Info.plist` fix
      (step 14).

### Code for step 8

> ⚠️ **Refinement on the pseudocode in the bullet above.** Don't call
> `markCollected` directly from the scan result. Split it: the scan sets a
> local `_verified` flag, and a separate **Complete order** button (enabled
> only once `_verified`) performs the state change. A scanner can misfire on a
> reflection or a neighbouring customer's screen, and a one-step flow makes
> that mistake instantly irreversible — the order is collected and the
> customer's food is gone. Two steps costs one tap and gives the vendor a
> chance to see the green tick before committing.

The host is a `StatefulWidget` because `_verified` is transient screen state
that must not survive a rebuild from the order stream:

```dart
class _DetailViewState extends State<_DetailView> {
  bool _verified = false;
```

**The scan.** Handle all three outcomes — dismissed, mismatch, match:

```dart
Future<void> _scan(FoodOrder order) async {
  final code = await Navigator.of(context).push<String>(
    MaterialPageRoute(builder: (_) => const QrScannerPage()),
  );
  if (code == null || !mounted) return;        // user backed out — do nothing
  final match = code.trim() == order.pickupCode.trim();
  setState(() => _verified = match);
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(match
          ? 'Code verified ✓ — you can complete the order.'
          : 'Code mismatch. Scanned "$code".'),
      backgroundColor: match ? AppColors.teal : AppColors.error,
    ),
  );
}
```

Three details that matter:

- **`.trim()` on both sides.** Some scanners append whitespace or a newline to
  the decoded payload, and an untrimmed compare fails a valid code with no
  visible reason.
- **Echo the scanned value back** in the mismatch message. "Code mismatch" on
  its own is undebuggable at a busy counter; showing what was actually read
  tells the vendor instantly whether they scanned the wrong customer's screen.
- **A mismatch sets `_verified = false`,** not just "does nothing" — a
  previously successful scan must be invalidated by a subsequent bad one.

**Manual entry**, which the reference repo lacks and you will want during the
live demo when a camera won't focus:

```dart
Future<void> _enterCodeManually(FoodOrder order) async {
  final controller = TextEditingController();
  final entered = await showDialog<String>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('Enter pickup code'),
      content: TextField(
        controller: controller,
        autofocus: true,
        textCapitalization: TextCapitalization.characters,
        decoration: const InputDecoration(hintText: 'e.g. A014'),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: () => Navigator.pop(ctx, controller.text),
          child: const Text('Verify'),
        ),
      ],
    ),
  );
  controller.dispose();
  if (entered == null || !mounted) return;
  final match =
      entered.trim().toUpperCase() == order.pickupCode.trim().toUpperCase();
  setState(() => _verified = match);
  /* ...same SnackBar as _scan... */
}
```

Case-insensitive here but not in `_scan`, because a human types `a014` and a
scanner does not. Dispose the controller — a dialog-local controller is still
a controller.

**Status-driven actions.** The screen shows exactly one primary action, chosen
by the order's current status:

```dart
switch (order.status) {
  case AppConstants.orderPreparing:
    // "Mark ready" -> vm.markReady(order.orderId)
  case AppConstants.orderReady:
    // "Scan to verify" -> _scan(order), plus a text button for manual entry,
    // then "Complete order" enabled only when _verified
  case AppConstants.orderCollected:
    // no actions — terminal state
}
```

```dart
ElevatedButton(
  onPressed: _verified ? () => _complete(vm, order.orderId) : null,
  child: const Text('Complete order'),
)
```

**Cancel, behind a confirmation** that names the money consequence:

```dart
Future<void> _cancel(VendorOrderDetailViewModel vm, FoodOrder order) async {
  final confirm = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('Cancel order?'),
      content: const Text(
        'The customer will be automatically refunded the full amount.',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx, false),
          child: const Text('Keep order'),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
          onPressed: () => Navigator.pop(ctx, true),
          child: const Text('Cancel & refund'),
        ),
      ],
    ),
  );
  if (confirm == true) {
    await vm.cancel(order);      // -> Mervin's cancelAndRefund transaction
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Order cancelled and refunded')),
      );
    }
  }
}
```

The destructive action is the `ElevatedButton` and the safe one is the
`TextButton` — but the *labels* carry the meaning ("Keep order" / "Cancel &
refund") rather than Yes/No, because "Cancel" in a dialog titled "Cancel
order?" is genuinely ambiguous.

Above the actions, render the full breakdown: pickup code and status chip,
customer name, `formatDateTime(order.createdAt)`, then per `OrderItem` the
quantity, name, chosen `customizations`, selected `addOns`,
`specialInstructions`, and `centsToRM(item.subtotal)` — finishing with
subtotal, service fee and `centsToRM(order.total)`. The vendor needs the
instructions visible without tapping anything; that is the whole point of the
screen for the kitchen.

# STEP 9 — `VendorOrderDetailViewModel` (1.5 h)

> **This replaces your step 8 stub.** Same getters, same three passthroughs;
> `order_detail_page.dart` should need zero edits. Delete the stub in this
> commit, and now wire the QR scanner's real result in place of the hardcoded
> string you built the page against.

- [ ] Constructor takes `orderId`, subscribes to `listenToOrder(orderId)`,
      holds `FoodOrder? _order` and `bool _loading`, `onError` handler,
      `dispose()` cancels.
- [ ] Passthrough methods: `markReady`, `markCollected`, `cancel(order)`.
- [ ] **Verify on a real device:** scan a customer's actual QR code and confirm
      the match succeeds, then confirm a *wrong* code is rejected. The rejection
      path is the one people forget to test and the one an examiner will try.

### Code for step 9

Structurally identical to step 7, but subscribed to a **single document**
rather than a query:

```dart
class VendorOrderDetailViewModel extends ChangeNotifier {
  final VendorOrderRepository _repository;
  StreamSubscription<FoodOrder?>? _sub;

  FoodOrder? _order;
  bool _loading = true;

  FoodOrder? get order => _order;
  bool get isLoading => _loading;

  VendorOrderDetailViewModel(String orderId,
      {VendorOrderRepository? repository})
      : _repository = repository ?? VendorOrderRepository() {
    _sub = _repository.listenToOrder(orderId).listen(
      (order) {
        _order = order;
        _loading = false;
        notifyListeners();
      },
      onError: (Object e) {
        debugPrint('VendorOrderDetailViewModel stream error: $e');
        _loading = false;
        notifyListeners();
      },
    );
  }

  Future<void> markReady(String orderId) => _repository.markReady(orderId);

  Future<void> markCollected(String orderId) =>
      _repository.markCollected(orderId);

  Future<void> cancel(FoodOrder order) => _repository.cancelOrder(order);

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }
}
```

`FoodOrder?` is nullable for a real reason: the document stream emits `null` if
the order is deleted while the screen is open. Render that as "order not
found" rather than letting a `!` throw.

The three passthroughs take an `orderId` (or order) argument rather than
closing over the constructor's, which lets the page call them for the order it
currently has in hand — worth keeping consistent even though they will always
match.

# STEP 10 — ⚠ `vendor_dashboard_page.dart` (12 h) — biggest file in the app

487 lines, but it is **two screens in one widget**, which is what makes it
long rather than hard. Build them separately.

> **Stub first (30 min — worth more here than anywhere else).** Write
> `VendorDashboardViewModel(vendorUid)` with `isLoading`, `hasStall`,
> `stall`, `activeOrders`, `todayOrderCount`, `todayRevenue`, and no-op
> `createStall(...)` / `setOpen(bool)` / `setPrepTime(int)`.
>
> Make `hasStall` a plain mutable field you can flip by hand. It is the switch
> between this file's two screens (10a and 10b), and being able to toggle it in
> one place is what lets you build both without creating and deleting stall
> documents in Firestore all afternoon. Step 11 replaces the insides.

**10a — the no-stall state (4 h)**
- [ ] Shown when `!vm.hasStall`. A create-stall `Form`: name, cuisine,
      description, prep time. On submit → `vm.createStall(...)`.
- [ ] After creation, show a clear "pending admin approval" state — the vendor
      must understand their stall isn't live yet. *(Justin's admin approves it;
      coordinate with him when testing.)*

**10b — the real dashboard (8 h)**
- [ ] Stall header: image, name, cuisine, rating + review count, status badge.
- [ ] An open/closed `Switch` → `vm.toggleOpen`, disabled while `vm.isUpdating`.
      ⚠ If the stall is `pending` or `suspended` the vendor must **not** be able
      to open it — guard on status, not just on the switch value.
- [ ] Prep-time control → `vm.updatePrepTime`.
- [ ] KPI tiles: `vm.todayOrderCount`, `centsToRM(vm.todayEarnings)`,
      active order count.
- [ ] A preview list of `vm.activeOrders` (first 3–5) with a "view all" into the
      order queue.
- [ ] Navigation into your other screens: menu management, order queue,
      earnings.
- [ ] Sign out via `context.read<AuthViewModel>().logout()`.

**Tip:** pull each section into its own small private widget
(`_StallHeader`, `_KpiRow`, `_ActiveOrdersPreview`). A 487-line `build` method
is both unreadable and very hard to defend in a Q&A; six 80-line widgets are
easy to explain one at a time.

### Code for step 10

**The top-level split** is one ternary — this is the "two screens in one
widget" the intro refers to:

```dart
final vm = context.watch<VendorDashboardViewModel>();
if (vm.loadingStall) return const LoadingIndicator();
return vm.hasStall ? const _DashboardTab() : const _CreateStallForm();
```

Take the tip seriously and declare these as separate private widgets:
`_StallHeader`, `_Banner`, `_StatsRow`, `_StatCard`, `_ActiveOrdersPreview`,
`_CreateStallForm`. Each is 40–80 lines and independently explainable.

⚠️ **10b — the open/closed guard.** This is the one piece of real logic on the
page, and the bullet above is easy to under-implement:

```dart
final stall = vm.stall!;
final isPending = stall.status == AppConstants.stallPending;
final isSuspended = stall.status == AppConstants.stallSuspended;
final canToggle = !isPending && !isSuspended;

// ...
if (canToggle)
  Column(
    children: [
      Switch(
        value: stall.status == AppConstants.stallOpen,
        onChanged: vm.isUpdating ? null : (v) => vm.toggleOpen(v),
      ),
      Text(
        stall.status == AppConstants.stallOpen ? 'Open' : 'Closed',
        style: AppTextStyles.caption,
      ),
    ],
  ),
```

Two separate disables, doing different jobs — don't collapse them:

- **`if (canToggle)` removes the switch entirely** for a pending or suspended
  stall. A vendor whose stall is awaiting approval or has been suspended by an
  admin must not be able to trade, and a greyed-out switch invites them to
  keep tapping it. Guarding on **status**, not on the switch's boolean, is the
  point of the bullet — `value: status == open` would render "closed" for a
  suspended stall and make opening look like a legitimate option.
- **`onChanged: vm.isUpdating ? null : ...`** disables it only during an
  in-flight write, so a double-tap can't queue two conflicting status writes.

Replace the switch with an explanatory banner in those states, so the screen
says *why* rather than just omitting a control:

```dart
if (isPending)
  _Banner(
    color: AppColors.orange,
    icon: Icons.hourglass_top,
    message: 'Your stall is awaiting admin approval. Customers cannot see '
        'it yet.',
  ),
if (isSuspended)
  _Banner(
    color: AppColors.error,
    icon: Icons.block,
    message: 'This stall has been suspended. Contact the food court admin.',
  ),
```

**The KPI row** — one `_StatCard` per figure, and every money value goes
through `centsToRM`:

```dart
Row(
  children: [
    Expanded(child: _StatCard(
      label: "Today's orders", value: '${vm.todayOrderCount}')),
    Expanded(child: _StatCard(
      label: 'Earnings', value: centsToRM(vm.todayEarnings))),
    Expanded(child: _StatCard(
      label: 'Active', value: '${vm.activeOrders.length}')),
  ],
)
```

Never render `vm.todayEarnings` directly — it is cents, and `85000` on a
dashboard reads as eighty-five thousand Ringgit. Your step 13 widget test
should assert the formatted string is present *and* that the raw integer is
absent.

**The active-orders preview** takes the first few and links out rather than
duplicating the queue:

```dart
final preview = vm.activeOrders.take(5).toList();
// ...one compact row per order, then:
TextButton(
  onPressed: () => Navigator.of(context).push(MaterialPageRoute(
    builder: (_) => OrderQueuePage(vendorUid: vm.vendorUid),
  )),
  child: Text('View all ${vm.activeOrders.length}'),
)
```

**10a — the create-stall form** is a `StatefulWidget` with its own
`GlobalKey<FormState>` and four controllers (name, cuisine, description, prep
time), disposed in `dispose()`. Submit:

```dart
Future<void> _submit() async {
  if (!_formKey.currentState!.validate()) return;
  await context.read<VendorDashboardViewModel>().createStall(
        name: _name.text.trim(),
        cuisine: _cuisine.text.trim(),
        description: _description.text.trim(),
        prepTimeMinutes: int.tryParse(_prepTime.text) ?? 15,
      );
  // No navigation needed — the stall stream fires, hasStall flips to true,
  // and the dashboard replaces this form on the next rebuild.
}
```

That comment is worth keeping. The reactive swap is the payoff of the whole
stream architecture, and it is the thing a marker is most likely to ask you to
walk through.

**Sign out** lives in the app bar:
`onPressed: () => context.read<AuthViewModel>().logout()` — `read`, not
`watch`, because a callback needs the object once and must not subscribe the
widget to auth changes.

# STEP 11 — `VendorDashboardViewModel` (3 h)

> **This replaces your step 10 stub.** You already know every getter's exact
> name and return type, because the dashboard has been consuming them for two
> weeks. All you are doing here is computing the real value instead of returning
> a hardcoded one. The page should need zero edits. Delete the stub in this
> commit.

- [ ] Constructor takes `vendorUid` and opens **two** subscriptions — the stall
      (`watchMyStall`) and all orders (`watchAllOrders`). Two separate
      `StreamSubscription` fields, both cancelled in `dispose()`.
- [ ] `hasStall` → `_stall != null`. The dashboard shows a *create stall* form
      when false and the real dashboard when true.
- [ ] `activeOrders` — status `preparing` or `ready`.
- [ ] `_todayOrders` — private getter filtering to today's calendar date
      (compare `year`/`month`/`day`, not a duration) **and excluding
      cancelled** orders.
- [ ] `todayOrderCount` → `_todayOrders.length`
- [ ] `todayEarnings` → **sum `o.vendorEarning` across `_todayOrders`.**
      ⚠ The reference repo recomputes this as `subtotal × (1 − stall rate)`,
      which is wrong once per-stall or historical rates differ. `vendorEarning`
      is stored on each order at place time by Mervin's `placeOrder` and is the
      truthful figure. One line, but know why.
- [ ] `toggleOpen(bool)`, `updatePrepTime(int)`, `createStall({...})`, each
      setting an `_updating` flag around the await so the UI can disable
      controls.

### Code for step 11

**Two subscriptions, two cancels.** Note only the *stall* stream clears
`_loadingStall` — the orders stream arriving late must not flip the page out
of its loading state before the stall is known:

```dart
VendorDashboardViewModel(this.vendorUid, {VendorOrderRepository? repository})
    : _repository = repository ?? VendorOrderRepository() {
  _stallSub = _repository.watchMyStall(vendorUid).listen(
    (stall) {
      _stall = stall;
      _loadingStall = false;
      notifyListeners();
    },
    onError: (Object e) {
      debugPrint('VendorDashboardViewModel stall stream error: $e');
      _loadingStall = false;
      notifyListeners();
    },
  );
  _ordersSub = _repository.watchAllOrders(vendorUid).listen(
    (orders) {
      _orders = orders;
      notifyListeners();
    },
    onError: (Object e) {
      debugPrint('VendorDashboardViewModel orders stream error: $e');
    },
  );
}

@override
void dispose() {
  _stallSub?.cancel();
  _ordersSub?.cancel();
  super.dispose();
}
```

`hasStall => _stall != null` is the switch between the two screens in step 10.

**The date filter compares calendar fields, not a duration:**

```dart
List<FoodOrder> get _todayOrders {
  final now = DateTime.now();
  return _orders.where((o) {
    final d = o.createdAt;
    return d.year == now.year &&
        d.month == now.month &&
        d.day == now.day &&
        o.status != AppConstants.orderCancelled;
  }).toList();
}
```

⚠️ `now.subtract(const Duration(hours: 24))` would be wrong: at 09:00 it
includes yesterday evening's orders, so "today's earnings" changes meaning
depending on when the vendor looks at it. A vendor reconciling their till at
close needs *this calendar day*.

Cancelled orders are excluded here, once, so every KPI built on `_todayOrders`
inherits the exclusion — a refunded order was never income.

⚠️ **`todayEarnings` sums the stored per-order figure:**

```dart
/// Today's gross earnings for this vendor (subtotal minus commission), cents.
int get todayEarnings =>
    _todayOrders.fold(0, (acc, o) => acc + o.vendorEarning);
```

The reference repo computes `subtotal × (1 − stall.commissionRate)` against
the stall's **current** rate. That is wrong the moment a rate changes: orders
placed last week get recomputed at today's rate, and the dashboard disagrees
with the wallet the vendor can actually withdraw from. `vendorEarning` is
written by Mervin's `placeOrder` at the instant of sale and is the only
truthful figure. One line, but it is a likely Q&A question — know why.

**The mutators** each guard on a null stall and flag `_updating` around the
await:

```dart
Future<void> toggleOpen(bool open) async {
  final stall = _stall;
  if (stall == null) return;
  _updating = true;
  notifyListeners();
  try {
    await _repository.setOpen(stall.stallId, open);
  } finally {
    _updating = false;
    notifyListeners();
  }
}
```

`createStall({name, cuisine, description, prepTimeMinutes})` follows the same
`_updating` / `try` / `finally` shape, forwarding `vendorUid` from the field.
The `finally` is what stops a failed write leaving the whole dashboard's
controls permanently disabled.

# STEP 12 — Earnings (6 h)

- [ ] **`EarningsRepository`** — thin view over Mervin's `WalletRepository`:
      `watchEarnings(vendorUid)` → `_wallet.watchTransactions(vendorUid, types:
      [txnEarning, txnWithdrawal, txnRefund])`, and `withdraw(uid, cents)` →
      `_wallet.withdraw(...)`. It filters the shared ledger to the entry types a
      vendor cares about; it does not have its own storage.
- [ ] **`EarningsViewModel`** — `earnings(vendorUid)` returning the stream, plus
      `withdraw(uid, cents)` with `_processing` and `_error` state. Catch the
      failure and set a friendly message; don't let the exception reach the UI.
- [ ] **`vendor_earnings_page.dart`** — total earned / total withdrawn /
      available balance summary; an `fl_chart` bar chart of daily earnings for
      the last 7 days; the transaction list with type icons, signed amounts and
      `formatDateTime`; and a withdraw dialog validating against the available
      balance.
- [ ] The withdrawal is simulated (no real payout) — say so in your user manual.

### Code for step 12

**`EarningsRepository` has no storage of its own** — it is a filtered view over
Mervin's shared ledger, which is the whole idea:

```dart
class EarningsRepository {
  final WalletRepository _wallet;

  EarningsRepository({WalletRepository? wallet})
      : _wallet = wallet ?? WalletRepository();

  static const _types = [
    AppConstants.txnEarning,
    AppConstants.txnWithdrawal,
    AppConstants.txnRefund,
  ];

  Stream<List<WalletTransaction>> watchEarnings(String vendorUid) {
    return _wallet.watchTransactions(vendorUid, types: _types);
  }

  Future<void> withdraw(String vendorUid, int amountCents) {
    return _wallet.withdraw(vendorUid, amountCents);
  }
}
```

`txnRefund` is in the list deliberately: when a customer's order is cancelled,
the vendor's earning is clawed back as a refund entry, and a vendor who can't
see those can't reconcile their balance.

**`EarningsViewModel`** is the same shape as Mervin's `WalletViewModel` —
`bool` return, friendly message, `finally` clearing the flag:

```dart
Future<bool> withdraw(String vendorUid, int amountCents) async {
  _error = null;
  _processing = true;
  notifyListeners();
  try {
    await _repository.withdraw(vendorUid, amountCents);
    return true;
  } catch (e) {
    _error = 'Withdrawal failed. Check your balance and try again.';
    return false;
  } finally {
    _processing = false;
    notifyListeners();
  }
}
```

`WalletRepository.withdraw` passes `requireFunds: true`, so an over-withdrawal
throws `InsufficientBalanceException` inside the transaction and **nothing** is
written — no balance change, no ledger row. Your catch turns that into a
message; the guard itself is not your code and must not be duplicated here.

**`vendor_earnings_page.dart` — the three summary figures** come from folding
the ledger by type:

```dart
int _sumOf(List<WalletTransaction> txns, String type) => txns
    .where((t) => t.type == type)
    .fold(0, (acc, t) => acc + t.amount);

final totalEarned = _sumOf(txns, AppConstants.txnEarning);
final totalWithdrawn = _sumOf(txns, AppConstants.txnWithdrawal);
```

⚠️ **Available balance is *not* `totalEarned - totalWithdrawn`.** Read it from
the vendor's user document via `AuthViewModel`, the same single source of
truth the customer wallet uses. Deriving it from the ledger drifts the moment
a refund or an admin adjustment lands, and then the vendor sees one number on
this page and a different one when a withdrawal is rejected.

**The 7-day chart** — bucket by calendar day, then render oldest-to-newest:

```dart
List<({DateTime day, int cents})> _lastSevenDays(List<WalletTransaction> txns) {
  final today = DateTime.now();
  return List.generate(7, (i) {
    final day = DateTime(today.year, today.month, today.day)
        .subtract(Duration(days: 6 - i));
    final cents = txns
        .where((t) =>
            t.type == AppConstants.txnEarning &&
            t.createdAt.year == day.year &&
            t.createdAt.month == day.month &&
            t.createdAt.day == day.day)
        .fold(0, (acc, t) => acc + t.amount);
    return (day: day, cents: cents);
  });
}
```

`List.generate` with `6 - i` gives you seven buckets in chronological order
including empty days — a chart that silently omits a zero day misrepresents
the trend. Feed these into `fl_chart`'s `BarChartGroupData`, converting cents
to Ringgit (`cents / 100`) for the axis so the labels read as money.

**The transaction list** signs the amount by type rather than storing negative
values:

```dart
final isDebit = txn.type == AppConstants.txnWithdrawal;
Text(
  '${isDebit ? '-' : '+'}${centsToRM(txn.amount)}',
  style: AppTextStyles.body.copyWith(
    color: isDebit ? AppColors.error : AppColors.teal,
  ),
)
```

`WalletTransaction.amount` is always positive — direction lives in `type`.
That is Mervin's convention from §0.3; respect it rather than storing signed
amounts, or the two roles will disagree about what a ledger row means.

**The withdraw dialog** validates against the available balance before
calling the view model:

```dart
final cents = rmToCents(controller.text);
if (cents == null || cents <= 0) return 'Enter a valid amount';
if (cents > availableBalance) return 'You only have ${centsToRM(availableBalance)}';
```

This is a courtesy check for a better message — the authoritative rejection
still happens inside the transaction. Say that if asked why you validate in
two places.

# STEP 13 — Your tests (5 h)

**Test only your own files.** Testing marks are per person.

Unit tests (`test/` mirroring your folder structure), using
`FakeFirebaseFirestore` — this is why every constructor takes an injectable
`db`:
- [ ] `test/vendor/menu_repository_test.dart` — `addItem` writes a document
      whose `itemId` matches its own id; `setAvailable` flips only that field;
      `deleteItem` removes it; `watchMenuItems` emits the current list.
- [ ] `test/vendor/menu_management_vm_test.dart` — starts loading, emits items,
      `isLoading` becomes false; `toggleAvailable` inverts the stored value.
- [ ] `test/vendor/order_queue_vm_test.dart` — orders split correctly into
      `preparing` and `ready`, and each bucket is sorted oldest-first.
- [ ] `test/vendor/vendor_dashboard_vm_test.dart` — `todayOrderCount` **excludes
      cancelled orders**; `todayEarnings` sums `vendorEarning`; yesterday's
      orders are excluded. (Construct `FoodOrder`s directly — no Firestore
      needed for the getters.)

Widget tests:
- [ ] `test/vendor/menu_management_page_test.dart` — renders `EmptyState` with
      no items, and a row per item when populated. Inject a fake VM.
- [ ] `test/vendor/order_queue_page_test.dart` — an order card displays its
      pickup code and formatted total.

### Code for step 13

**A shared `order({...})` factory** at the top of each file keeps every test to
the field it is actually about:

```dart
FoodOrder order({
  required String id,
  String status = 'preparing',
  int vendorEarning = 630,
  DateTime? createdAt,
}) {
  final created = createdAt ?? DateTime.now();
  return FoodOrder(
    orderId: id,
    customerUid: 'cust1',
    customerName: 'Alice',
    stallId: 'stall1',
    vendorUid: 'vend1',
    stallName: 'Nasi Corner',
    subtotal: 700,
    serviceFee: 50,
    total: 750,
    commissionRate: 0.10,
    vendorEarning: vendorEarning,
    status: status,
    pickupCode: 'A001',
    createdAt: created,
    updatedAt: created,
  );
}
```

**`test/vendor/menu_repository_test.dart`** — `MenuRepository(db: db)` with a
`FakeFirebaseFirestore` is the entire setup. The id-round-trip test proves the
convention from step 3:

```dart
test('addItem writes a document whose itemId matches its own id', () async {
  final repo = MenuRepository(db: db);

  final item = await repo.addItem(
    stallId: 'stall1',
    name: 'Fried Rice',
    description: 'Wok-fried',
    price: 800,
    category: 'Mains',
  );

  final stored = await db
      .collection('stalls').doc('stall1')
      .collection('menuItems').doc(item.itemId)
      .get();

  expect(stored.exists, isTrue);
  expect(stored.data()!['itemId'], item.itemId);
  expect(stored.data()!['price'], 800);
});
```

⚠️ The `setAvailable` test asserts on the fields it should **not** have
touched — that is what makes it a test of the targeted `update` rather than
just a test that the flag changed:

```dart
test('setAvailable flips only that field', () async {
  final repo = MenuRepository(db: db);
  final item = await repo.addItem(
    stallId: 'stall1', name: 'Fried Rice', description: 'Wok-fried',
    price: 800, category: 'Mains',
  );

  await repo.setAvailable('stall1', item.itemId, false);

  final stored = await db
      .collection('stalls').doc('stall1')
      .collection('menuItems').doc(item.itemId)
      .get();
  expect(stored.data()!['available'], false);
  expect(stored.data()!['name'], 'Fried Rice');
  expect(stored.data()!['price'], 800);
});
```

Plus `deleteItem` → `expect(stored.exists, isFalse)`.

**`test/vendor/menu_management_vm_test.dart`** — the two rules for testing a
stream-backed view model:

```dart
test('starts loading, emits items, then isLoading is false', () async {
  final repo = MenuRepository(db: db);
  await repo.addItem(
    stallId: 'stall1', name: 'Fried Rice', description: '',
    price: 800, category: 'Mains',
  );

  final vm = MenuManagementViewModel('stall1', repository: repo);
  addTearDown(vm.dispose);
  expect(vm.isLoading, isTrue);          // nothing has arrived yet

  await Future<void>.delayed(Duration.zero);

  expect(vm.isLoading, isFalse);
  expect(vm.items, hasLength(1));
  expect(vm.items.first.name, 'Fried Rice');
});
```

⚠️ `addTearDown(vm.dispose)` on **every** view model you construct, and
`await Future<void>.delayed(Duration.zero)` after constructing one. A view
model that loads via a stream has loaded nothing at the moment its constructor
returns; assert before the delay and you are testing the initial state, not
the loaded one. Asserting `isLoading` is `true` *before* the delay is worth
keeping — it proves the loading state exists at all.

`toggleAvailable` is verified through Firestore, not through the view model,
because the view model deliberately holds no local copy:

```dart
await vm.toggleAvailable(vm.items.first);
await Future<void>.delayed(Duration.zero);

final stored = await db
    .collection('stalls').doc('stall1')
    .collection('menuItems').doc(item.itemId).get();
expect(stored.data()!['available'], false);
```

**`test/vendor/order_queue_vm_test.dart`** — seed four orders with deliberately
shuffled timestamps so a passing test genuinely proves the sort:

```dart
test('splits into preparing and ready, each oldest-first', () async {
  final base = DateTime.now().subtract(const Duration(minutes: 30));
  final orders = [
    order(id: 'p-new', createdAt: base.add(const Duration(minutes: 10))),
    order(id: 'p-old', createdAt: base),
    order(id: 'r-new', status: 'ready',
        createdAt: base.add(const Duration(minutes: 15))),
    order(id: 'r-old', status: 'ready',
        createdAt: base.add(const Duration(minutes: 5))),
  ];
  for (final o in orders) {
    await db.collection('orders').doc(o.orderId).set(o.toJson());
  }

  final vm = OrderQueueViewModel('vend1',
      repository: VendorOrderRepository(db: db));
  addTearDown(vm.dispose);
  await Future<void>.delayed(Duration.zero);

  expect(vm.preparing.map((o) => o.orderId), ['p-old', 'p-new']);
  expect(vm.ready.map((o) => o.orderId), ['r-old', 'r-new']);
});
```

Inserting `p-new` before `p-old` matters — seed them already in order and the
assertion passes even with the sort deleted.

**`test/vendor/vendor_dashboard_vm_test.dart`** — the bullet suggests
constructing `FoodOrder`s directly, but the getters read `_orders`, which is
private and stream-fed, so go through the fake anyway. It costs three extra
lines:

```dart
test('todayOrderCount excludes cancelled and yesterday', () async {
  final now = DateTime.now();
  final orders = [
    order(id: 'a', status: 'collected', createdAt: now),
    order(id: 'b', status: 'cancelled', createdAt: now),
    order(id: 'c', status: 'collected',
        createdAt: now.subtract(const Duration(days: 1))),
  ];
  for (final o in orders) {
    await db.collection('orders').doc(o.orderId).set(o.toJson());
  }

  final vm = VendorDashboardViewModel('vend1',
      repository: VendorOrderRepository(db: db));
  addTearDown(vm.dispose);
  await Future<void>.delayed(Duration.zero);

  expect(vm.todayOrderCount, 1);
});

test('todayEarnings sums the stored vendorEarning', () async {
  final now = DateTime.now();
  final orders = [
    order(id: 'a', status: 'collected', vendorEarning: 630, createdAt: now),
    order(id: 'b', status: 'collected', vendorEarning: 200, createdAt: now),
    order(id: 'c', status: 'cancelled', vendorEarning: 999, createdAt: now),
  ];
  for (final o in orders) {
    await db.collection('orders').doc(o.orderId).set(o.toJson());
  }

  final vm = VendorDashboardViewModel('vend1',
      repository: VendorOrderRepository(db: db));
  addTearDown(vm.dispose);
  await Future<void>.delayed(Duration.zero);

  expect(vm.todayEarnings, 630 + 200);
});
```

The `vendorEarning: 999` on the cancelled order is the trap — it is a value no
correct implementation can produce, so if it ever appears in the total you
know cancelled orders leaked into the sum.

> ⚠️ **`FakeFirebaseFirestore` does not enforce composite indexes.**
> `watchVendorOrders` combines `where('vendorUid')` with
> `orderBy('createdAt')`, which real Firestore rejects until the index in
> `firestore.indexes.json` is deployed. Your tests will pass against a missing
> index; the app will throw at runtime. Test the queue on a device too, and if
> you see a `FAILED_PRECONDITION` with a console URL, that link creates the
> index for you.

**Widget tests.** Both pages read a view model from a provider, so inject a
fake and let the test own disposal:

```dart
class FakeMenuVm extends ChangeNotifier implements MenuManagementViewModel {
  FakeMenuVm(this._items);
  final List<MenuItem> _items;

  @override
  List<MenuItem> get items => _items;
  @override
  bool get isLoading => false;
  @override
  String get stallId => 'stall1';

  @override
  noSuchMethod(Invocation i) => super.noSuchMethod(i);
}

Future<void> pumpMenu(WidgetTester tester, List<MenuItem> items) {
  final vm = FakeMenuVm(items);
  addTearDown(vm.dispose);
  return tester.pumpWidget(
    MaterialApp(
      home: ChangeNotifierProvider<MenuManagementViewModel>.value(
        value: vm,
        child: const MenuManagementPage(stallId: 'stall1'),
      ),
    ),
  );
}
```

`implements` plus a `noSuchMethod` fallback means you override only the three
members the widget reads instead of stubbing the whole class. Then
`pumpMenu(tester, [])` finds `EmptyState`, and a two-item list finds two rows.

For `order_queue_page_test.dart`, assert on the **formatted** money and that
the raw cents are absent:

```dart
expect(find.text('#A001'), findsOneWidget);
expect(find.text('RM 7.50'), findsOneWidget);
expect(find.text('750'), findsNothing);
```

# STEP 14 — ⚠ iOS permission fix (0.5 h) — **assigned to you**

> **Platform reality.** You develop and test on Android — the team has no Mac
> or iPhone. But the iOS project stays correct and buildable, because a
> friend's Mac may be available for a one-off check. The *fix* below is plain
> XML you can write on Windows today; the *verification* is opportunistic.

Both camera features in the app are yours, so this defect is yours.
`ios/Runner/Info.plist` currently declares **neither** required usage string.
On iOS, touching the camera or photo library without one is an **instant hard
crash**, not a permission denial.

- [ ] Add inside the top-level `<dict>` of `ios/Runner/Info.plist`:
      ```xml
      <key>NSCameraUsageDescription</key>
      <string>StallHop uses the camera to scan customer pickup QR codes and to photograph your menu items.</string>
      <key>NSPhotoLibraryUsageDescription</key>
      <string>StallHop needs photo library access so you can choose an existing photo for a menu item.</string>
      ```
      Write a real, specific reason. Apple rejects vague strings, and a vague
      one is a weak Q&A answer too.
- [ ] **Verify on Android** — that's steps 4b and 9, and it's your real,
      available-today testing.
- [ ] **If you can borrow a Mac + iPhone, book the session deliberately.** It
      is ~20 minutes: `flutter build ios`, run on device, open the QR scanner
      (step 8), then add-item → pick image → camera and gallery (step 2b).
      Screenshot it. Do this before the report deadline — a verified fix beats
      a plausible one, and this is the only defect of the three whose fix you
      cannot otherwise prove.
- [ ] **Report whichever actually happened.** Verified → show the evidence.
      Not verified → *"the missing iOS usage-description strings were
      identified and corrected by inspection; the fix could not be validated at
      runtime within the project window as the team has no macOS/iOS hardware.
      Android is the target platform for all testing evidence."* Never claim a
      test you didn't run.
- [ ] Be able to explain the **platform difference**, which you can answer fully
      either way: on Android, `mobile_scanner` and `image_picker` merge their
      own permission declarations into the manifest at build time (which is why
      `AndroidManifest.xml` only declares `POST_NOTIFICATIONS`), whereas iOS
      requires a static usage-description string per sensitive API or the OS
      terminates the app on first access. Also know that **Firebase Test Lab's
      Robo pass cannot catch this**, because Robo is Android-only (Test Lab
      uses XCUITest for iOS) — which is exactly why this step is manual.

# STEP 15 — Report deliverables (4 h)

- [ ] ~9 screenshots: vendor dashboard, create stall, menu management,
      add/edit item, image picker, order queue, order detail, QR scanner,
      earnings. Consistent device size, light theme, seeded data so nothing
      looks empty. Name them `NN_vendor_screenname.png`.
- [ ] Vendor-flow wireframes.
- [ ] Vendor section of the user manual.
- [ ] Your test evidence (screenshots of your suite passing).

---

## Effort summary

| Step | Slice | File | Hours |
|---|---|---|---|
| 1 | Menu | `menu_management_page.dart` (on a stub VM) | 4 |
| 2 | Menu | ⚠ `add_edit_item_page.dart` (on the same stub) | **12** |
| 3 | Menu | `menu_repository.dart` | 3 |
| 4 | Menu | `menu_management_vm.dart` (replaces stub) | 2 |
| 5 | Orders | `order_queue_page.dart` (on a stub VM) | 5 |
| 6 | Orders | `vendor_order_repository.dart` | 4 |
| 7 | Orders | `order_queue_vm.dart` (replaces stub) | 2 |
| 8 | Detail | `order_detail_page.dart` (QR, on a stub VM) | 9 |
| 9 | Detail | `order_detail_vm.dart` (replaces stub) | 1.5 |
| 10 | Dashboard | ⚠ `vendor_dashboard_page.dart` (on a stub VM) | **12** |
| 11 | Dashboard | `vendor_dashboard_vm.dart` (replaces stub) | 3 |
| 12 | Earnings | earnings (repo + VM + page) — **logic first** | 6 |
| 13 | — | tests | 5 |
| 14 | — | iOS `Info.plist` | 0.5 |
| 15 | — | report assets | 4 |
| | | **Total** | **~68 h** |

Every slice runs **UI → repository → real ViewModel** except earnings (12),
which runs logic-first because it moves money.

**The two hardest files are steps 2 and 10**, at 12 h each — a third of your
total between them. `add_edit_item_page.dart` is hard because of genuine
complexity (form + upload + two nested dynamic editors); `vendor_dashboard_page.dart`
is hard mainly because of size. Break both into the sub-steps above and start
step 2 early — do not leave it to the final week. Being able to build both
against a stub ViewModel, before `MenuRepository` exists, is the main reason
the UI-first order is worth it for you specifically.

---

## Deviations from the reference repo (say these in the Q&A if asked)

1. **`createStall` writes `commissionRate: null` instead of a hardcoded 0.10.**
   The reference hardcodes it, which is precisely why the admin's commission
   setting never affects pricing. `null` means "inherit the venue default".
2. **`todayEarnings` sums the stored `vendorEarning`** instead of recomputing
   from the stall's current rate. The stored value is what was actually
   credited; recomputing gives the wrong answer for any order placed at a
   different rate.
3. Optionally split the two large pages into private sub-widgets. Same
   behaviour, far easier to explain — recommended, and worth mentioning as a
   deliberate readability decision rather than an accident.
