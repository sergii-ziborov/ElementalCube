import SwiftUI
import ElementalCore

/// Local visual QA, opened only with --preview-portraits.
struct MonsterPortraitGallery:View {
    var body:some View {
        ScrollView {
            VStack(spacing:22) {
                Text("Пять стихий. Пять характеров.").font(.system(size:25,design:.serif)).multilineTextAlignment(.center)
                LazyVGrid(columns:[GridItem(.adaptive(minimum:145,maximum:210))],spacing:16) {
                    ForEach(ElementForm.allCases) { form in
                        VStack(spacing:8) {
                            MonsterPortrait(form:form,interactive:true).frame(width:116,height:130).accessibilityIdentifier("portrait."+form.rawValue)
                            Text(form.name).font(.system(size:18,design:.serif))
                        }.padding(14).frame(maxWidth:.infinity).background(.white.opacity(0.45),in:RoundedRectangle(cornerRadius:22))
                    }
                }
            }.padding(22).frame(maxWidth:750)
        }.frame(maxWidth:.infinity,maxHeight:.infinity).foregroundStyle(ink).background(cream)
    }
}
