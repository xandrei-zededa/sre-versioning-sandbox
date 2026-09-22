# RFC & Rollout Plan: Семантическое версионирование Terraform-модулей в sre

> **Статус:** Proof of Concept завершен со 100% успехом
> **Живой прототип (GitHub):** [https://github.com/xandrei-zededa/sre-versioning-sandbox](https://github.com/xandrei-zededa/sre-versioning-sandbox)
> **Влияние на существующий продакшен `zededa/sre`:** 0% (полная обратная совместимость)

---

## 1. Зачем это нужно команде (Ключевые преимущества)

| Проблема сейчас (относительные пути `../../`) | Как будет после внедрения |
| :--- | :--- |
| Любой коммит в модуль мгновенно аффектит **все 27 кластеров одновременно** («русская рулетка»). | Прод зафиксирован на стабильном теге (например, `v1.0.0`). Эксперименты в модулях не могут задеть прод. |
| Нельзя безопасно протестировать фичу только на `madmax` (dev). | **Canary-выкатка:** `madmax` обновляется на `v1.1.0`, прод остается на `v1.0.0`. |
| Чтобы проверить логику HCL, нужно запускать долгий plan через AWS. | **`tofu test` с `mock_provider`** проверяет условия и regex-валидации за **1.1 секунды** локально (0 вызовов в AWS). |
| Откат при аварии — судорожный `git revert` в `main`. | **Откат за 30 секунд:** меняем тег `v1.1.0 -> v1.0.0` в `terragrunt.hcl`. |

---

## 2. Как с этим работать инженеру («Zero Friction»)

Разработчику **НЕ нужно** вручную ставить теги, писать changelog или возиться с релизами.

```text
1. Локальная разработка:
   $ cd terraform-modules/parts/aws/aws_eks
   $ tofu test    # мгновенная проверка логики на моках (1 сек)

2. Проверка плана с локальным кодом (без выпуска релиза!):
   $ TG_SOURCE=../../../../terraform-modules//parts/aws/aws_eks terragrunt plan

3. Коммит по стандарту Conventional Commits:
   $ git commit -m "feat(aws-eks): add karpenter node role support"

4. Открытие PR в GitHub:
   - Автоматический Matrix CI проверяет форматирование, Trivy SAST и tofu test.
   - Semantic PR Linter проверяет заголовок коммита.
   - Мерж в main.

5. ВСЁ ОСТАЛЬНОЕ ДЕЛАЕТ АВТОМАТИКА:
   - Release Please сам выпустит релиз: modules/aws-eks-v1.1.0.
   - Сгенерирует CHANGELOG.md.
   - Renovate обновит интерактивный Dependency Dashboard в GitHub Issues.
```

---

## 3. Защита от спама (Dependency Dashboard)

В репозитории **НЕ создаются** десятки неконтролируемых PR от ботов.
Вместо этого Renovate держит **один единственный Issue — [Dependency Dashboard](https://github.com/xandrei-zededa/sre-versioning-sandbox/issues/4)**:

```markdown
## Active Module Updates
- [ ] Update modules/aws-eks to v1.1.0 in development/zedcloud-madmax
- [ ] Update modules/aws-eks to v1.1.0 in production/zedcloud-production
```

Инженер ставит галочку `[x]` напротив dev-кластера $\rightarrow$ **только тогда создается 1 аккуратный PR**. После проверки в Dev процедура повторяется для Production.

---

## 4. Пошаговый план внедрения в `zededa/sre` (Без риска)

```text
[ Фаза 1: Пилот на песочнице (1 спринт) ]
  1. Добавить .github/workflows/ci.yml, release-please.yml, semantic-pr.yml.
  2. Добавить release-please-config.json ТОЛЬКО с одним пилотным модулем:
     terraform-modules/parts/sandbox-test.
  3. Существующие 65 модулей и 27 кластеров остаются на относительных путях (0 изменений).

[ Фаза 2: Пилот первого боевого модуля (1 спринт) ]
  1. Добавить unit.tftest.hcl в terraform-modules/parts/aws/aws_eks.
  2. Добавить aws_eks в release-please-config.json.
  3. Перевести только dev-кластер madmax на тег git::...ref=modules/aws-eks-v1.0.0.
  4. Убедиться, что terragrunt plan показывает 0 to add, 0 to change, 0 to destroy.

[ Фаза 3: Постепенный перевод остальных модулей ]
  По мере необходимости инженеры добавляют свои модули в конфиг и тегируют их.
```

---

## 5. Доказательная база (Что уже работает вживую в песочнице)

* **Репозиторий:** [xandrei-zededa/sre-versioning-sandbox](https://github.com/xandrei-zededa/sre-versioning-sandbox)
* **Живые релизы Release Please:** [Releases Page](https://github.com/xandrei-zededa/sre-versioning-sandbox/releases)
* **Параллельный Matrix CI:** [Action Run #35752434851](https://github.com/xandrei-zededa/sre-versioning-sandbox/actions/runs/35752434851)
* **Интерактивный дашборд:** [Issue #4](https://github.com/xandrei-zededa/sre-versioning-sandbox/issues/4)
* **Canary Plan Dev vs Prod:** Успешно доказан на уровне Terragrunt.
