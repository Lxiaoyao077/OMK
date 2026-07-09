import type { MdDialog, MdFilledButton, MdOutlinedButton } from '@material/web/all'
import { PolicyEditor } from '../app_list/policy'
import { Config, type SectionKey } from '../config'
import { applyDialogAnimation } from './animation'

export class SectionDialog {
  #dialog: MdDialog | null = null
  #policyEditor: PolicyEditor | null = null
  #config: Config
  #section: Exclude<SectionKey, 'trust_record'>
  #dialogId: string

  constructor(config: Config, section: Exclude<SectionKey, 'trust_record'>, dialogId: string) {
    this.#config = config
    this.#section = section
    this.#dialogId = dialogId
  }

  getElement(): DocumentFragment {
    const template = document.createElement('template')
    template.innerHTML = /* html */ `
      <md-dialog id="${this.#dialogId}">
        <div slot="headline">${this.#config.getSectionTitle(this.#section)}</div>
        <div slot="content">
          <div class="policy-fields" id="${this.#dialogId}-fields">
            ${PolicyEditor.html(this.#config.getSectionSchema(this.#section))}
          </div>
        </div>
        <div slot="actions">
          <md-outlined-button id="${this.#dialogId}-close">Cancel</md-outlined-button>
          <md-filled-button id="${this.#dialogId}-save">Save</md-filled-button>
        </div>
      </md-dialog>
    `

    const fragment = template.content
    this.#dialog = fragment.querySelector<MdDialog>(`#${this.#dialogId}`)

    const fieldsContainer = fragment.querySelector<HTMLElement>(`#${this.#dialogId}-fields`)!    
    this.#policyEditor = new PolicyEditor(fieldsContainer, this.#config.getSectionSchema(this.#section))
    this.#policyEditor.bind()

    fragment.querySelector<MdOutlinedButton>(`#${this.#dialogId}-close`)!.onclick = () => this.close()
    fragment.querySelector<MdFilledButton>(`#${this.#dialogId}-save`)!.onclick = () => {
      void this.#save()
    }

    return fragment
  }

  initAnimation(): void {
    if (this.#dialog) applyDialogAnimation(this.#dialog)
  }

  show(): void {
    this.#policyEditor?.setPolicy((this.#config.get(this.#section) as Record<string, string | boolean>) ?? null)
    this.#dialog?.show()
  }

  close(): void {
    this.#dialog?.close()
  }

  async #save(): Promise<void> {
    if (!this.#policyEditor?.isValid()) return
    const policy = this.#policyEditor.getPolicy(true)
    if (!policy) return
    this.#config.set(this.#section, policy)
    await this.#config.write()
    this.close()
  }
}
