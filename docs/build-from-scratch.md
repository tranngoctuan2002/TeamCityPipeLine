# Buổi demo 2: dựng TeamCity pipeline từ đầu tới cuối

Buổi 1 cho thấy pipeline **làm được gì**: project được import sẵn từ `settings.kts`. Buổi 2 cho thấy pipeline **được dựng ra sao**: bắt đầu từ một project rỗng, bấm từng màn hình, chạy sau mỗi chặng, và kết thúc bằng việc xem lại tất cả dưới dạng code.

- **Vai trò hiện tại:** tài liệu **tham khảo** cho Demo2 trong [demo-guide.md](demo-guide.md). Dựng sẵn Demo2 tới chặng 8 (bỏ chặng 6 SonarQube, phần đó làm ở Demo1) trước giờ demo. Trên sân khấu chỉ làm live chặng 1-2 (project, Git, một step đầu, Run), rồi dạo qua các chặng còn lại. View as code (chặng 11) làm ở Demo1.
- **Thời lượng nếu dựng đủ:** khoảng 65 phút. Nếu chỉ có 30 phút, dựng sẵn chặng 1-3 trước giờ demo rồi bắt đầu từ chặng 4.
- **Cách dựng:** bằng giao diện, vì khán giả nhìn thấy từng khái niệm. Toàn bộ script trong `scripts/` dùng lại nguyên vẹn, không viết thêm code.
- **Sản phẩm cuối:** 3 build configuration giống project đã import (CI build, Deploy to Staging, Deploy to Production), và CI build có thêm phân tích code bằng SonarQube.

> Nhãn giao diện lấy từ tài liệu TeamCity 2026.2, chưa kiểm tra trên server thật. Những chỗ ghi *(kiểm tra khi tập)* là nhãn tài liệu không nêu rõ. Hãy tập đủ một lần và sửa lại file này theo đúng màn hình của bạn.

## Chuẩn bị

Máy đã có đủ theo [setup-guide.md](setup-guide.md): Visual Studio, IIS với 3 site, TeamCity, agent đã authorize.

Hôm trước:
- [ ] Tập đủ một lần, rồi **xoá project vừa tập** để buổi thật bắt đầu từ trống. Lần tập này cũng làm nóng NuGet cache.
- [ ] Sửa các nhãn *(kiểm tra khi tập)* trong file này.
- [ ] Mở Docker Desktop và tải sẵn image, khoảng 1 GB: `docker compose -f sonarqube/docker-compose.yml pull`.
- [ ] Sau khi tập, xoá dữ liệu SonarQube để buổi thật bắt đầu từ trống: `docker compose -f sonarqube/docker-compose.yml down -v`.

30 phút trước giờ demo:
- [ ] Mở Docker Desktop, đóng bớt ứng dụng nặng (TeamCity và SonarQube cùng chạy khá tốn RAM), rồi bật SonarQube: `docker compose -f sonarqube/docker-compose.yml up -d`. Nó cần vài phút, nên bật sớm để tới chặng 6 là sẵn sàng.
- [ ] **Tạm dừng trigger của project đã import**, nếu không mỗi lần push cả hai pipeline sẽ cùng deploy vào một site. Mở project > bật edit mode (công tắc góc trên bên phải) > **Actions** > **Pause / Activate...**. Làm cho từng subproject nếu cần, rồi kiểm tra cả 4 build đều hiện trạng thái paused.
- [ ] `git tag -f demo2-start; git push -f origin demo2-start` để có điểm quay lại.
- [ ] Mở sẵn các tab: TeamCity, http://localhost:9000, http://localhost:8082, http://localhost:8083, thư mục repo, `.teamcity/settings.kts`.

Phương án dự phòng: project đã import chính là bản hoàn chỉnh. Nếu kẹt ở chặng nào, mở build tương ứng trong đó để giải thích, hoặc **Activate** trigger lại và chạy tiếp từ đó.

## Chặng 0. Bức tranh chung (3 phút)

Vẽ sơ đồ này và giữ trên màn hình cả buổi:

```
Project
 ├─ VCS root ───────────── lấy code ở đâu
 └─ Build configuration ── một công việc: CI build, Deploy...
      ├─ Build steps ───── làm gì, theo thứ tự
      ├─ Triggers ──────── khi nào tự chạy
      ├─ Parameters ────── giá trị thay đổi được, secret
      ├─ Build features ── tính năng thêm: đọc kết quả test
      └─ Dependencies ──── nối các build thành chuỗi

Server: lưu cấu hình, xếp hàng build.   Agent: máy thật sự chạy build.
```

**Câu chốt:** "Dựng pipeline chỉ là trả lời 5 câu hỏi: lấy code ở đâu, làm gì, khi nào làm, cần giá trị gì, và nối với build nào."

## Chặng 1. Tạo project và kết nối Git (4 phút)

1. Bấm **Create** cạnh mục **Projects** ở thanh bên.
2. Name: `Pipeline from scratch` > **Create**. Project ID tự sinh.
3. Trang **Set up your build**: chọn **From any Git URL**.
4. URL: `https://github.com/tranngoctuan2002/TeamCityPipeLine.git`. Xác thực HTTPS: anonymous nếu repo public, token nếu repo private.
5. Name: `CI build`. Default branch: `refs/heads/main`.
6. **Tắt** lựa chọn tự chạy khi có thay đổi mới, vì chặng 7 sẽ thêm trigger bằng tay.
7. **Create**.

**Bẫy:** repo có sẵn thư mục `.teamcity`, nên TeamCity có thể đề nghị import. Buổi này **đừng import**, nếu không project sẽ thành bản sao của buổi 1. Nếu TeamCity tự gợi ý build step, cũng bỏ qua. *(kiểm tra khi tập)*

**Giải thích:** bước này tạo ra một **VCS root**, tức địa chỉ repo mà nhiều build configuration dùng chung. TeamCity định kỳ hỏi GitHub xem có commit mới không.

## Chặng 2. Build step đầu tiên (5 phút)

Mở **Build Steps** > thêm step *(kiểm tra khi tập)* > runner **PowerShell**.

Mọi step PowerShell trong buổi này dùng chung các giá trị sau:

| Trường | Giá trị | Vì sao |
| --- | --- | --- |
| Platform | `x64` | Đây là mặc định. Khớp với MSBuild 64-bit trong `common.ps1` |
| Edition | `Desktop` | Windows PowerShell 5.1, có sẵn trên agent |
| Script | `File` | Logic nằm trong Git, không dán vào TeamCity |
| Script execution mode | **Execute .ps1 script from external file** | Chỉ chế độ này có **Script arguments** |

Step đầu tiên:

| Step name | Script file | Script arguments |
| --- | --- | --- |
| Check tools | `scripts/check-tools.ps1` | *(trống)* |

Bấm **Run**, mở build, xem **Build Log**. Chỉ cho khán giả:
- Agent nào nhận build.
- Dòng checkout, và commit đang được build.
- Log tìm thấy MSBuild, rồi dòng `##teamcity[setParameter ...]`.

**Giải thích service message:** script chỉ cần in ra một dòng theo cú pháp `##teamcity[...]` là nói chuyện được với TeamCity. Đây là cách nó truyền đường dẫn MSBuild cho các step sau.

## Chặng 3. Restore, build và đánh version (6 phút)

Thêm 2 step:

| Step name | Script file | Script arguments |
| --- | --- | --- |
| Restore NuGet | `scripts/restore.ps1` | *(trống)* |
| Build + version | `scripts/build.ps1` | `-Configuration Release -Version %build.number%` |

Sau đó:
1. **General Settings** > **Build number format**: `1.0.%build.counter%`.
2. **Version Control Settings** > tick **Delete all files in the checkout directory before the build**. `build.ps1` sửa `AssemblyInfo.cs` ngay trong thư mục checkout, nên mỗi build phải bắt đầu từ bản sạch.

**Run**. Chỉ cho khán giả số build mới dạng `1.0.N`.

**Giải thích `%...%`:** đây là tham chiếu parameter, TeamCity thay giá trị trước khi chạy step. `%build.number%` có sẵn, còn `%build.counter%` tự tăng 1 sau mỗi build. Cùng một con số sẽ đi vào file DLL, tên file zip, chân trang web và `/Health.ashx`.

## Chặng 4. Unit test và tab Tests (5 phút)

| Step name | Script file | Script arguments |
| --- | --- | --- |
| Unit tests | `scripts/test.ps1` | `-Configuration Release` |

Riêng step này chưa đủ: TeamCity chỉ thấy script thoát với mã 0 hay khác 0. Để có tab Tests:

1. **Build Features** > thêm **XML report processing**.
2. **Report type:** loại dành cho file `.trx`. Trong `settings.kts` là `VSTEST`. *(kiểm tra khi tập: tên trong danh sách có thể khác)*
3. **Monitoring rules:** `TestResults/*.trx`.

**Run**. Mở tab **Tests**: 7 test passed.

**Giải thích:** build step là việc **chạy**, còn build feature là việc **thêm hành vi xung quanh** build, ở đây là đọc file kết quả. Test fail thì script thoát với mã khác 0, các step sau bị bỏ qua.

## Chặng 5. Quality gate và artifact (5 phút)

| Step name | Script file | Script arguments |
| --- | --- | --- |
| Quality gate | `scripts/quality-gate.ps1` | *(trống)* |

**General Settings:**
1. **Artifact paths:** `out/publish/** => DemoApp.Web.%build.number%.zip`. Bên trái `=>` là file cần lấy, bên phải là tên zip, TeamCity tự nén.
2. **Publish artifacts:** đổi thành **Only if build status is successful**.

**Bẫy, nên nói to:** mặc định là **Even if build fails**. Nếu không đổi, một build fail vẫn sinh ra zip có thể bị deploy nhầm.

**Run**. Mở tab **Artifacts**: `DemoApp.Web.1.0.N.zip`.

**Giải thích:** artifact là thứ duy nhất đi tiếp sang các bước deploy. Từ đây trở đi không biên dịch lại nữa.

## Chặng 6. SonarQube: dựng server và nối vào CI (10 phút)

> **Chưa chạy thử.** Các script và file Docker đã có trong repo, nhưng chuỗi begin, build, end chưa chạy với server thật. Hãy tập kỹ chặng này. Tên các bước tạo project dựa trên tài liệu SonarQube, nên có thể khác nhẹ.

Unit test kiểm tra code **chạy đúng không**. SonarQube kiểm tra code **viết tốt không**: bug tiềm ẩn, lỗ hổng bảo mật, code khó bảo trì.

**6.1 Bật server.** Cho khán giả xem `sonarqube/docker-compose.yml`, rồi kiểm tra container đã chạy:

```powershell
docker compose -f sonarqube/docker-compose.yml ps
```

Mở http://localhost:9000, đăng nhập `admin` / `admin` và đổi mật khẩu theo yêu cầu.

**6.2 Tạo project.** **Projects** > **Create Project** > **Local Project**:
- Display name: `DemoApp`
- Project key: `demoapp`
- Main branch: `main`, vì mặc định có thể là `master`
- New code: giữ **Previous version**, nếu được hỏi. *(kiểm tra khi tập)*

**6.3 Tạo token.** **User** > **My Account** > **Security**. Chọn type **Project analysis**, project `DemoApp`, rồi **Generate**. **Copy ngay**, vì token chỉ hiện một lần.

**6.4 Parameters của CI build:**

| Tên | Kind | Value type | Giá trị |
| --- | --- | --- | --- |
| `sonar.url` | Configuration parameter | Text | `http://localhost:9000` |
| `sonar.key` | Configuration parameter | Text | `demoapp` |
| `env.SONAR_TOKEN` | Environment variable | **Password** | token vừa tạo |

**6.5 Thêm 2 step:**

| Step name | Script file | Script arguments |
| --- | --- | --- |
| SonarQube begin | `scripts/sonar-begin.ps1` | `-HostUrl %sonar.url% -ProjectKey %sonar.key% -Version %build.number%` |
| SonarQube end | `scripts/sonar-end.ps1` | *(trống)* |

**Bẫy, thứ tự là bắt buộc:** step mới nằm cuối danh sách, nên phải sắp xếp lại. Thứ tự đúng:

1. Check tools
2. Restore NuGet
3. **SonarQube begin**
4. Build + version
5. Unit tests
6. **SonarQube end**
7. Quality gate

**Run**. Trong log step **SonarQube end**, TeamCity chờ kết quả Quality Gate. Mở http://localhost:9000, project `DemoApp` hiện dashboard và trạng thái Quality Gate.

**Giải thích:**
- **Vì sao có begin và end:** scanner phân tích code C# **trong lúc** MSBuild biên dịch. `begin` gài vào MSBuild, build diễn ra như thường, `end` gom kết quả gửi lên server.
- **Quality Gate:** bộ tiêu chí pass/fail của SonarQube. Script bật `sonar.qualitygate.wait=true`, nên gate fail thì step fail, không có artifact, Staging không chạy. Nếu không bật, gate fail mà build vẫn xanh.
- **Sonar way chấm code mới:** không có issue mới, mọi Security Hotspot mới đã được review, coverage từ 80%, trùng lặp tối đa 3%. Hai điều kiện sau được bỏ qua khi có dưới 20 dòng mới.
- **`-Version`:** số build thay đổi mỗi lần, nên SonarQube phân biệt được code mới với code cũ.
- **Scanner:** được ghim phiên bản trong `dotnet-tools.json`, và `sonar-begin.ps1` tự cài bằng `dotnet tool restore`, nên agent không phải cài thêm.

**Bẫy khác:**
- Từ lúc này, SonarQube tắt thì CI đỏ ở bước begin. Đây là cái giá của việc thêm một cổng kiểm tra.
- Pipeline **chưa gửi coverage**. Commit từ 20 dòng mới trở lên có thể làm gate fail vì điều kiện 80%. Các commit demo chỉ sửa một dòng nên không bị ảnh hưởng.
- Nếu `end` báo không thu được thông tin project, kiểm tra `begin` và build có chạy cùng thư mục và cùng tài khoản không.

## Chặng 7. Tự chạy khi có push (2 phút)

**Triggers** > thêm **VCS Trigger** > **Branch filter:** `+:<default>`.

**Giải thích:**
- `<default>` là nhánh mặc định của VCS root, tức `main`. Push lên nhánh khác sẽ không chạy.
- Sau khi push, build chưa chạy ngay. TeamCity cần lần hỏi GitHub kế tiếp, cộng thêm quiet period mặc định 60 giây để gom các commit liền nhau. Thường chờ 1-2 phút. Chặng 10 sẽ thử thật.

CI build đã xong. Tóm tắt cho khán giả bằng cách mở lại trang **Build Steps**: 7 step, mỗi step chỉ gọi một script.

## Chặng 8. Deploy to Staging (10 phút)

Đây là chặng chính, nơi các build được nối thành chuỗi.

**8.1 Tạo build configuration.** Trong project, chọn **Create build configuration** > **Manually**. Name: `Deploy to Staging`.

**8.2 Gắn repo.** **Version Control Settings** > gắn VCS root đã có. Build này không biên dịch, nó chỉ cần code để lấy các script deploy.

**8.3 Đổi loại.** Trong **General Settings**, đổi type thành **Deployment**. Từ giờ nút chạy tên là **Deploy**, và mỗi lúc chỉ có 1 build chạy, nên hai lần deploy không ghi đè lên nhau.

**8.4 Parameters.** Tab **Parameters** > **Add new parameter**:

| Tên | Kind | Value type | Giá trị |
| --- | --- | --- | --- |
| `deploy.env` | Configuration parameter | Text | `Staging` |
| `deploy.path` | Configuration parameter | Text | `C:\inetpub\cicd-demo-staging` |
| `deploy.url` | Configuration parameter | Text | `http://localhost:8082` |
| `env.DEMO_API_KEY` | Environment variable | **Password** | một chuỗi demo, ví dụ `staging-demo-key-2026` |

**Giải thích secret:**
- Kind **Environment variable** đưa giá trị vào biến môi trường, nên `deploy.ps1` đọc được mà không để lộ trên dòng lệnh.
- **Password** ẩn giá trị khỏi giao diện, log và code DSL.
- TeamCity che log bằng cách tìm và thay chuỗi, nên đừng dùng giá trị ngắn như `123`, kẻo những chỗ khác trong log cũng bị che.
- Ở đây gõ thẳng giá trị vì cấu hình không nằm trong Git. Token `credentialsJSON:` của buổi 1 chỉ cần khi cấu hình nằm trong Git.

**8.5 Build steps:**

| Step name | Script file | Script arguments |
| --- | --- | --- |
| Config + deploy | `scripts/deploy.ps1` | `-ArtifactDir artifact -TargetPath "%deploy.path%" -Environment %deploy.env%` |
| Smoke test | `scripts/smoke-test.ps1` | `-Url %deploy.url%` |
| Set build status | `scripts/set-status.ps1` | `-Environment %deploy.env%` |

**8.6 Dependencies.** Đây là phần quan trọng nhất, nên giải thích chậm.

*Snapshot dependency* > **Depend on:** `CI build`:

| Trường | Giá trị |
| --- | --- |
| Only use successful builds from suitable ones | bật |
| On failed dependency | **Mark build as failed to start** |

*Artifact dependency* > **Depend on:** `CI build`:

| Trường | Giá trị |
| --- | --- |
| Get artifacts from | **Build from the same chain** |
| Artifact rules | `DemoApp.Web.*.zip => artifact` |
| Clean destination paths before downloading artifacts | bật |

**Hai loại dependency khác nhau thế nào:**
- **Snapshot** trả lời "**cùng commit nào**": gắn deploy với đúng một CI build của cùng commit đó, và không chạy nếu CI fail.
- **Artifact** trả lời "**lấy file gì**": tải zip của CI build đó về thư mục `artifact/`.
- Dùng chung hai loại thì deploy luôn nhận đúng zip đã qua test.

**Bẫy:** nếu không bật **Clean destination paths**, zip cũ còn lại trong `artifact/` và `deploy.ps1` sẽ dừng với lỗi "Expected exactly one". Nhờ vậy nó không deploy nhầm phiên bản, ví dụ sau khi rollback.

**8.7 Trigger.** **Triggers** > thêm **Finish Build Trigger**:
- **Build configuration:** `CI build`
- **Trigger after successful build only:** bật
- **Branch filter:** `+:<default>`

**8.8 Chạy.** Bấm **Deploy**. Trong log, chỉ các dòng:
- `Deploying version 1.0.N to Staging`
- `Smoke test passed: OK 1.0.N`

Rồi mở http://localhost:8082, footer hiện `Staging` và `Version 1.0.N`. Mở `C:\inetpub\cicd-demo-staging\Web.config`: key được ghi lúc deploy, còn `src/DemoApp.Web/Web.config` trong Git vẫn trống.

## Chặng 9. Deploy to Production (4 phút)

Không dựng lại, chỉ copy. Đây là lý do chặng 8 đưa mọi thứ khác nhau vào parameter.

1. Mở **Deploy to Staging** > cài đặt > **Actions** > copy build configuration *(kiểm tra khi tập)*. Name: `Deploy to Production`.
2. **Parameters:** `deploy.env` = `Production`, `deploy.path` = `C:\inetpub\cicd-demo-production`, `deploy.url` = `http://localhost:8083`.
3. Gõ lại `env.DEMO_API_KEY` bằng **key của Production**.
4. **Triggers:** **xoá** Finish Build Trigger. Production chỉ chạy bằng tay, và đây chính là bước phê duyệt.
5. Bấm **Deploy**, rồi mở http://localhost:8083.

Mở tab **Build Chains** của project để xem chuỗi CI > Staging và CI > Production.

**Giải thích:** với nhiều môi trường hơn, nên dùng **build template** thay vì copy. Trong `settings.kts` phần này là class `DeployBuild`.

## Chặng 10. Chạy thử toàn chuỗi (6 phút)

**Thay đổi tốt:**

```powershell
git merge origin/demo/1-new-headline -m "New headline"
git push
```

Chờ 1-2 phút. CI build tự chạy, Deploy to Staging tự chạy sau đó, mở http://localhost:8082 thấy tiêu đề mới. Production vẫn đứng yên cho tới khi bạn bấm **Deploy**. Trên http://localhost:9000, project `DemoApp` có thêm một lần phân tích với version mới.

**Thay đổi có lỗi:**

```powershell
git merge origin/demo/2-discount-bug -m "Apply discount change"
git push
```

CI đỏ ở **Unit tests**, tab Tests có 3 test fail, không có artifact, Staging không chạy, http://localhost:8082 vẫn là **90.00**. Step **SonarQube end** cũng bị bỏ qua, nên SonarQube không có lần phân tích nào cho commit này.

**Rollback:** mở **Deploy to Staging** > **Run custom build** > tab **Dependencies** > chọn CI build cũ > chạy. Trong log, smoke test kiểm đúng phiên bản cũ.

**Bẫy:**
- Đừng bấm **Deploy** thường lúc này: commit mới nhất là commit lỗi, TeamCity sẽ chạy CI cho nó và CI fail.
- Hộp thoại chỉ hiện tối đa 20 build.
- Build của loại Deployment cũng có nút **Redeploy** trong mục Deployments. Xem thử khi tập, nếu tiện hơn thì dùng nó.

## Chặng 11. Từ giao diện sang code (5 phút)

1. Mở cài đặt của **CI build** > bấm **View as code** ở thanh bên. TeamCity hiện Kotlin của đúng cấu hình vừa bấm.
2. Mở `.teamcity/settings.kts` bên cạnh và đối chiếu. Hai step SonarQube cũng có trong `settings.kts` (step 3 và 6), nhưng có điều kiện `sonar.enabled = true` và mặc định tắt, để project đã import vẫn chạy khi SonarQube tắt:

| Màn hình vừa bấm | Dòng trong `settings.kts` |
| --- | --- |
| Git URL, Default branch | `object DemoRepo : GitVcsRoot({ ... })` |
| Build number format | `buildNumberPattern = "1.0.%build.counter%"` |
| Artifact paths | `artifactRules = "out/publish/** => ..."` |
| Publish artifacts | `publishArtifacts = PublishMode.SUCCESSFUL` |
| Delete all files in the checkout directory | `cleanCheckout = true` |
| Step PowerShell | `powerShell { scriptMode = file { path = "..." } }` |
| XML report processing | `features { xmlReport { ... } }` |
| VCS Trigger | `triggers { vcs { branchFilter = "+:<default>" } }` |
| Deployment type | `type = BuildTypeSettings.Type.DEPLOYMENT` |
| Password parameter | `password("env.DEMO_API_KEY", apiKeyToken)` |
| Snapshot dependency | `dependency(ImprovedCi) { snapshot { ... } }` |
| Artifact dependency | `artifacts { cleanDestination = true ... }` |
| Finish Build Trigger | `finishBuildTrigger { ... }` |
| Copy sang Production | `object DeployProduction : DeployBuild(...)` |

3. Muốn lấy toàn bộ project: **Actions** > **Download settings in Kotlin format...**.

**Câu chốt:** "Giao diện để học và thử, code để giữ lâu dài: có lịch sử, có review, và dựng lại được trên server khác."

Muốn lưu cấu hình trong Git thì cần cả `.teamcity/pom.xml`: TeamCity dùng nó để biên dịch `settings.kts`. Thiếu nó, TeamCity báo `did not produce .teamcity/generated_settings.zip artifact`.

## Build configuration hay Pipelines (YAML)?

Sẽ có người hỏi câu này. TeamCity 2026.2 đưa **Pipelines** thành tính năng chính thức, nên cần phân biệt: "pipeline" trong buổi này là chuỗi build configuration, không phải tính năng đó.

| | Build configuration (buổi này) | Pipelines |
| --- | --- | --- |
| Cấu hình lưu ở | XML hoặc Kotlin DSL | YAML, sửa được ngay trong TeamCity |
| Build step | Đầy đủ, có PowerShell | Mặc định ít hơn: Script, Maven, Gradle, Node.js, .NET |
| Finish Build Trigger | Có | Không |
| Build Approval | Có | Chưa có |
| Phù hợp | Quy trình phức tạp | Quy trình đơn giản, khoảng 10-15 build |
| Đổi qua lại | Không chuyển đổi được | Không chuyển đổi được |

Dự án này dùng build configuration vì cần trigger sau khi CI xong, cần loại Deployment, và cần rollback bằng cách chọn CI build cũ. Tài liệu Pipelines không nói về loại Deployment hay rollback kiểu đó. Bạn có thể thử Pipelines sau với một dự án đơn giản hơn. Xem [so sánh của JetBrains](https://www.jetbrains.com/help/teamcity/2026.2/create-and-edit-pipelines.html).

## Câu hỏi có thể gặp

**Vì sao phải có script, sao không gõ lệnh vào TeamCity?**
Script nằm trong Git, được review, chạy được trên laptop, và mang sang CI khác được. TeamCity chỉ điều phối.

**Có cần 3 build configuration không, một cái có được không?**
Một cái thì mỗi lần deploy lại phải build lại, và không tách được bước bấm tay cho Production.

**Vì sao không dùng Finish Build Trigger một mình?**
Trigger chỉ quyết định **khi nào** chạy. Snapshot dependency mới đảm bảo **đúng commit**, nên tài liệu TeamCity khuyên dùng chung cả hai.

**Vì sao Staging cần repo nếu không biên dịch?**
Để lấy `scripts/`, và snapshot dependency giữ script đó cùng commit với artifact.

**Bản miễn phí đủ không?**
Bản Professional có 3 agent và tối đa 100 build configuration. Buổi này dùng 3. SonarQube Community Build cũng miễn phí.

**Đã có `quality-gate.ps1`, sao cần thêm SonarQube?**
Hai thứ kiểm tra hai việc khác nhau. `quality-gate.ps1` tìm secret trong file config. SonarQube phân tích code C#. Chạy cả hai vì một cái rất nhanh và không cần server, một cái sâu hơn.

**Vì sao SonarQube chạy trong CI build, không phải deploy?**
Nó cần theo dõi lúc biên dịch, và chỉ cần chạy một lần cho mỗi commit. Build deploy không biên dịch.

**SonarQube có phân tích pull request được không?**
Community Build chỉ phân tích nhánh chính, nên khớp với CI đang chạy trên `main`. Phân tích theo nhánh và pull request cần bản trả phí.

**Vì sao chạy bằng Docker?**
Một lệnh là có server đúng phiên bản, không phải cài Java. Dữ liệu nằm trong Docker volume, xoá sạch được bằng `down -v`. Cấu hình trong repo dùng database nhúng, chỉ phù hợp cho demo.

## Sau buổi demo

1. **Activate** lại trigger của project đã import nếu bạn vẫn dùng nó.
2. Đưa `main` về trước demo. Cách này viết lại lịch sử `main` trên GitHub, nên chỉ dùng cho repo demo:

```powershell
git reset --hard demo2-start
git push --force-with-lease origin main
```

3. Xoá project `Pipeline from scratch` nếu định tập lại.
4. Tắt SonarQube để giải phóng RAM: `docker compose -f sonarqube/docker-compose.yml stop`. Dùng `down -v` nếu muốn xoá cả dữ liệu.
