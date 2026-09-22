# Архитектура и эксплуатация монорепозитория Terraform/Terragrunt: Полное руководство от А до Я

> **Для кого этот документ:** Для SRE-инженеров, DevOps, системных архитекторов и разработчиков любого уровня.  
> **Цель руководства:** На простых жизненных примерах, схемах и практических сценариях объяснить, как устроена платформа версионирования модулей, почему она на 100% защищает продакшен от человеческих ошибок и как выполнять любую повседневную задачу без стресса и риска.

---

## Оглавление
1. [Проблема: Как устроена жизнь «до» (Антипаттерн относительных путей)](#1-проблема-как-устроена-жизнь-до)
2. [Архитектурная модель: Как устроена жизнь «после»](#2-архитектурная-модель-как-устроена-жизнь-после)
3. [Роли компонентов системы (Кто за что отвечает)](#3-роли-компонентов-системы)
4. [Сценарий 1: Разработка новой фичи в модуле (Zero-Cloud Mocking)](#4-сценарий-1-разработка-новой-фичи-в-модуле)
5. [Сценарий 2: Локальная проверка плана ДО релиза (TG_SOURCE оверрайд)](#5-сценарий-2-локальная-проверка-плана-до-релиза)
6. [Сценарий 3: Создание коммита и Pull Request (Matrix CI & Guards)](#6-сценарий-3-создание-коммита-и-pull-request)
7. [Сценарий 4: Как работает авто-релиз (Release Please Bot)](#7-сценарий-4-как-работает-авто-релиз)
8. [Сценарий 5: Поэтапная Canary-выкатка в кластеры (Self-Hosted Renovate)](#8-сценарий-5-поэтапная-canary-выкатка-в-кластеры)
9. [Сценарий 6: Разные версии одного модуля в разных Dev-кластерах](#9-сценарий-6-разные-версии-одного-модуля-в-разных-dev-кластерах)
10. [Сценарий 7: Мгновенный аварийный откат (Rollback за 30 секунд)](#10-сценарий-7-мгновенный-аварийный-откат)
11. [Сценарий 8: Почему GitHub может требовать "Approve and run" и как это выключить](#11-сценарий-8-почему-github-требует-approve-and-run)
12. [Шпаргалка инженера (Quick Reference Table)](#12-шпаргалка-инженера)

---

## 1. Проблема: Как устроена жизнь «до»

### Историческое состояние монорепозитория
В репозитории есть папка с общими модулями `terraform-modules/parts/aws/aws_eks/`.  
Все 27 боевых кластеров (включая production-кластер `tmna`, стейджинг и дев-кластер `madmax`) ссылаются на эту папку через обычные относительные пути файловой системы:

```hcl
# terragrunt/deployments/production/tmna/cluster/terragrunt.hcl
terraform {
  source = "../../../../../terraform-modules//parts/aws/aws_eks"
}
```

### Чем это опасно («Эффект домино»):
```text
  [ Инженер правит aws_eks ] ──► [ Мержит в main для dev-кластера madmax ]
                                                │
                 ┌──────────────────────────────┴──────────────────────────────┐
                 ▼                                                             ▼
     [ dev-кластер madmax ]                                        [ production кластер tmna ]
     Применяет изменение...                                       Atlantis / Jenkins подтягивает main...
                                                                   💥 ОШИБКА: Затерся Security Group!
                                                                   💥 РЕЗУЛЬТАТ: Падение продакшена!
```

1. **Невозможно изолировать эксперимент:** Любой коммит в `main` сразу же становится кодовой базой для всех 27 кластеров.
2. **Страх трогать код:** Инженеры боятся оптимизировать модули, потому что цена опечатки — глобальная авария.
3. **Невозможность Canary-выкатки:** Нельзя проверить новую версию модуля сначала на `madmax`, понаблюдать неделю и только потом перевести прод.
4. **Тяжелый откат:** При аварии приходится делать экстренный `git revert` в `main`, рискуя затереть чужие коммиты.

---

## 2. Архитектурная модель: Как устроена жизнь «после»

В целевой архитектуре код модуля и его применение в кластерах **полностью разделены через неизменяемые Git-теги (Semantic Versioning)**.

```text
               terraform-modules/parts/aws/aws_eks
                                │
                  [ Release Please Авторелиз ]
                                │
               ┌────────────────┴────────────────┐
               ▼                                 ▼
   modules/aws-eks-v1.0.0            modules/aws-eks-v1.2.0
        (Стабильная)                      (Новая с Karpenter)
               │                                 │
               ▼                                 ▼
    [ Production Clusters ]             [ Dev Cluster: madmax ]
   Прод зафиксирован на v1.0.0         Тестирует v1.2.0 в изоляции
   ИММУНИТЕТ К ИЗМЕНЕНИЯМ В MAIN!      Остальные 26 кластеров в безопасности!
```

В файле `terragrunt.hcl` каждого кластера теперь прописан точный URL с тегом:
```hcl
terraform {
  source = "git::https://github.com/zededa/sre.git//terraform-modules/parts/aws/aws_eks?ref=modules/aws-eks-v1.0.0"
}
```
**Главное правило безопасности:** Что бы ни происходило в ветке `main`, продакшен будет брать **строго код из тега `v1.0.0`**. Прод становится изолированным островком стабильности.

---

## 3. Роли компонентов системы

Чтобы система работала автоматически и не создавала бюрократии, в репозитории настроены 4 ключевых инструмента:

1. **OpenTofu Mock Provider (`tofu test`):**
   * Встроенный инструмент тестирования. Перехватывает вызовы к AWS/GCP и подменяет их моками.
   * Позволяет запускать тесты на ноутбуке за 1 секунду без облачных доступов.
2. **Release Please (Google APIs):**
   * Бот-релиз менеджер. Анализирует сообщения коммитов (`feat:`, `fix:`).
   * Сам высчитывает номер следующей версии SemVer (`1.1.0` $\rightarrow$ `1.2.0`), сам обновляет `CHANGELOG.md` и сам ставит теги в Git. Инженеру не нужно тегировать вручную.
3. **Self-Hosted Renovate Runner:**
   * Сканирует репозиторий прямо внутри GitHub Actions по расписанию и по требованию.
   * Видит появление новых тегов модулей и предлагает их обновление по группам (`Canary Dev` $\rightarrow$ `Staging` $\rightarrow$ `Production`).
4. **Destructive Plan Guard & Trivy:**
   * Сканирует HCL на уязвимости (открытые порты, избыточные права IAM).
   * Блокирует деплой, если в плане случайно появляется удаление (`destroy > 0`) критических баз данных или нод.

---

## 4. Сценарий 1: Разработка новой фичи в модуле

### Задача: Добавить поддержку Intelligent-Tiering в модуль `s3-bucket`

1. Создаем рабочую ветку:
   ```bash
   git checkout -b feat/s3-tiering
   ```
2. Открываем файл `terraform-modules/parts/aws/s3-bucket/main.tf` и пишем код:
   ```hcl
   variable "enable_intelligent_tiering" {
     type        = bool
     description = "Enable S3 Intelligent-Tiering"
     default     = false
   }

   resource "aws_s3_bucket_intelligent_tiering_configuration" "this" {
     count  = var.enable_intelligent_tiering ? 1 : 0
     bucket = aws_s3_bucket.this.id
     name   = "EntireBucket"
     tiering {
       access_tier = "ARCHIVE_ACCESS"
       days        = 90
     }
   }
   ```
3. Открываем юнит-тест `terraform-modules/parts/aws/s3-bucket/tests/unit.tftest.hcl` и добавляем проверку:
   ```hcl
   mock_provider "aws" {}

   run "verify_tiering_active" {
     command = plan
     variables {
       bucket_name                = "test-bucket"
       enable_intelligent_tiering = true
     }
     assert {
       condition     = length(aws_s3_bucket_intelligent_tiering_configuration.this) == 1
       error_message = "Tiering block must be created"
     }
   }
   ```
4. Запускаем мгновенную проверку локально:
   ```bash
   cd terraform-modules/parts/aws/s3-bucket
   tofu test
   ```
   **Результат:** Тест выполнился за 1.1 секунды. 0 вызовов в AWS. Вы на 100% уверены, что синтаксис HCL и логика условия `count` работают.

---

## 5. Сценарий 2: Локальная проверка плана ДО релиза

Самый частый вопрос инженера:  
*«Я написал код модуля, но тег еще не выпущен. Как мне посмотреть, что покажет `terragrunt plan` на тестовом кластере `madmax`?»*

Для этого в Terragrunt есть встроенный механизм локального оверрайда — флаг или переменная `TG_SOURCE`:

```bash
cd terragrunt/deployments/development/zedcloud-madmax/cluster

# Временно подменяем Git-тег на локальную папку с диска:
TG_SOURCE=../../../../../terraform-modules//parts/aws/aws_eks terragrunt plan
```

### Что делает эта команда:
1. Terragrunt **временно игнорирует строку `ref=...`** в файле `terragrunt.hcl`.
2. Он берет ваш незакоммиченный код прямо из соседней папки `terraform-modules/` на диске.
3. Строит честный diff с реальным стейтом dev-кластера.
4. Вы видите точный план изменений своими глазами еще **до того**, как создали PR или выпустили релиз!

---

## 6. Сценарий 3: Создание коммита и Pull Request

В репозитории действует стандарт **Conventional Commits**. Сообщение коммита — это инструкция для релизного бота.

### Формат коммита:
```text
<тип>(<модуль>): <краткое описание>
```

| Что вы сделали | Пример коммита | Какую версию выпустит бот |
| :--- | :--- | :--- |
| Добавили новую функциональность | `git commit -m "feat(s3-bucket): add intelligent tiering support"` | **MINOR** (`v1.1.0` $\rightarrow$ `v1.2.0`) |
| Исправили баг / опечатку | `git commit -m "fix(s3-bucket): fix lifecycle expiration days"` | **PATCH** (`v1.1.0` $\rightarrow$ `v1.1.1`) |
| Ломающее изменение (Breaking change) | `git commit -m "feat(s3-bucket)!: change required bucket name prefix"` | **MAJOR** (`v1.1.0` $\rightarrow$ `v2.0.0`) |

### Допустимые скоупы (имена модулей):
`aws-eks`, `irsa-role`, `rds-postgres`, `s3-bucket`, `sandbox-test`.

### Что происходит при открытии PR:
В GitHub Actions автоматически запускается **Matrix CI**:
* `OpenTofu Format Check` (`tofu fmt -check`) — следит за стилем кода.
* `Trivy Security Scan` — проверяет HCL на уязвимости и открытые порты.
* `terraform-docs` — автоматически генерирует документацию модуля.
* `Unit Tests` — параллельно прогоняет `tofu test` на моках для всех модулей.
* `Validate PR Title` — следит, чтобы заголовок PR соответствовал Conventional Commits.

После получения аппрува вы нажимаете **Squash and Merge** в ветку `main`.

---

## 7. Сценарий 4: Как работает авто-релиз

Вам **НЕ нужно** идти в терминал и руками писать `git tag ...` или руками создавать релиз на GitHub.

1. Как только ваш PR влился в `main`, запускается воркфлоу **Release Please**.
2. Бот видит коммит `feat(s3-bucket): ...`.
3. Он автоматически открывает специальный PR:  
   👉 `chore: release main`
4. Внутри этого PR бот сам:
   * Поднял версию в `.release-please-manifest.json`: `1.1.0 -> 1.2.0`.
   * Добавил запись с описанием вашей фичи в `terraform-modules/parts/aws/s3-bucket/CHANGELOG.md`.
5. Тимлид или автор нажимает кнопку **Merge** на этом Release PR.
6. В этот момент бот автоматически:
   * Создает официальный Git-тег: **`modules/s3-bucket-v1.2.0`**.
   * Публикует официальный **GitHub Release** с историей изменений.

---

## 8. Сценарий 5: Поэтапная Canary-выкатка в кластеры

После выпуска релиза `modules/s3-bucket-v1.2.0` новый код нужно доставить в кластеры.  
Здесь подключается **Self-Hosted Renovate Runner**.

### Как это устроено без спама:
Бот ведет единый пульт управления — **[Issue #18: Dependency Dashboard](https://github.com/xandrei-zededa/sre-versioning-sandbox/issues/18)**.

```text
                        Выпущен новый тег v1.2.0
                                    │
                                    ▼
                     [ Self-Hosted Renovate Runner ]
                                    │
       ┌────────────────────────────┴────────────────────────────┐
       ▼                                                         ▼
[ ШАГ 1: Canary PR в Dev ]                             [ ШАГ 2: Прод в безопасности ]
Открыт PR для madmax/alpha.                            Production НЕ ТРОГАЕТСЯ!
diff: v1.1.0 -> v1.2.0                                 Прод ждет вашей отмашки в дашборде.
```

### Порядок действий инженера:
1. Заходим в открытый ботом PR для Canary Dev Clusters.
2. Смотрим вкладку *Files changed* — там изменена ровно одна строчка `ref=...` в файле деплоймента `madmax`.
3. Atlantis строит план. Мы проверяем diff и мёржим PR.
4. Dev-кластер обновился на `v1.2.0`. Мы проверяем его работоспособность в течение нескольких дней.
5. Всё стабильно? Заходим в дашборд или открываем PR для `staging` и `production`.
6. Мёржим прод только тогда, когда лично убедились в стабильности на тестовом контуре!

---

## 9. Сценарий 6: Разные версии одного модуля в разных Dev-кластерах

Частая ситуация: *«Инженер А тестирует кардинально новую версию EKS на кластере `madmax`, а Инженеру Б для тестирования приложений на кластере `alpha` нужна стабильная старая версия»*.

В монорепозитории это решается тривиально, потому что каждый кластер имеет **свой собственный независимый файл `terragrunt.hcl`**:

* **Кластер `madmax` (Canary):**
  ```hcl
  # terragrunt/deployments/development/zedcloud-madmax/cluster/terragrunt.hcl
  terraform {
    source = "git::https://github.com/zededa/sre.git//terraform-modules/parts/aws/aws_eks?ref=modules/aws-eks-v1.2.0"
  }
  ```
* **Кластер `alpha` (Стабильный dev):**
  ```hcl
  # terragrunt/deployments/development/zedcloud-alpha/cluster/terragrunt.hcl
  terraform {
    source = "git::https://github.com/zededa/sre.git//terraform-modules/parts/aws/aws_eks?ref=modules/aws-eks-v1.0.0"
  }
  ```

Они живут в одном репозитории, в одном каталоге `development/`, но используют **разные версии модуля одновременно**. Никаких конфликтов!

---

## 10. Сценарий 7: Мгновенный аварийный откат

### Ситуация:
Вы обновили кластер в проде до версии `v1.2.0`. Через час выяснилось, что новый релиз содержит непредвиденную проблему с сетью. Нужно срочно откатиться.

### Как происходил откат раньше:
Паника, поиск виновных коммитов в `main`, опасный `git revert`, который ломает код других инженеров.

### Как происходит откат сейчас (Ровно 30 секунд):
1. Открываем `terragrunt/deployments/production/tmna/cluster/terragrunt.hcl`.
2. Меняем одну цифру в теге:
   ```hcl
   # Было:
   source = "...?ref=modules/aws-eks-v1.2.0"

   # Стало (откатились на предыдущую заведомо рабочую версию):
   source = "...?ref=modules/aws-eks-v1.1.0"
   ```
3. Создаем PR $\rightarrow$ Atlantis применяет план $\rightarrow$ Кластер мгновенно вернулся в стабильное состояние. Кодовая база модулей при этом даже не открывалась.

---

## 11. Сценарий 8: Почему GitHub требует "Approve and run"

### Что это за сообщение:
Иногда в закладке Actions на Pull Request от Renovate появляется желтая плашка:  
> *«1 workflow awaiting approval — This workflow requires approval from a maintainer.»*

### Причина:
Это стандартная политика безопасности GitHub для защиты от спама: если ветка создана внешним ботом или токеном, GitHub ставит запуск тестов на паузу, чтобы не расходовать ваши минуты раннеров без вашего ведома.

### Как отключить это требование навсегда:
1. Перейдите в: **Settings $\rightarrow$ Actions $\rightarrow$ General** репозитория.
2. Прокрутите до секции **«Fork pull request workflows from outside collaborators»**.
3. Выберите пункт:  
   👉 **`Require approval for first-time contributors with no prior commits`**  
   *(вместо «Require approval for all outside collaborators»)*.
4. После этого все авто-PR от ботов будут сразу прогонять CI без ручных подтверждений.

---

## 12. Шпаргалка инженера

| Действие | Команда / Ссылка | Время выполнения |
| :--- | :--- | :--- |
| **Быстрый юнит-тест модуля (моки)** | `cd terraform-modules/parts/... && tofu test` | **~1.1 сек** (0 вызовов в облако) |
| **Проверка стиля HCL** | `tofu fmt -check terraform-modules` | **0.1 сек** |
| **Проверка безопасности Trivy** | `trivy config --severity HIGH,CRITICAL terraform-modules` | **~0.8 сек** |
| **Локальный оверрайд плана в Terragrunt** | `TG_SOURCE=<путь_к_модулю> terragrunt plan` | По скорости Terragrunt |
| **Прогон всех pre-commit проверок** | `pre-commit run --all-files` | **~3 сек** |
| **Сквозная интерактивная демо-проверка** | `./scripts/demo-walkthrough.sh` | **~5 сек** |
| **Пульт управления обновлениями** | **[Dependency Dashboard (Issue #18)](https://github.com/xandrei-zededa/sre-versioning-sandbox/issues/18)** | Интерактивно в UI |
